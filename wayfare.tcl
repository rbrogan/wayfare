package provide wayfare 2.0
package require Tclx
package require gen

namespace eval WayfareNS {

variable Off 0
variable DebugOn 0
variable LoggingTable "wayfare_logging"
variable DeletedTable "wayfare_deleted"
variable TestTable "wayfare_test"

proc Debug {Message} {
     if {$WayfareNS::DebugOn != 0} {
          puts $Message
     }
}

# Configures which sqlite database to use. 
proc ConfigDatabase {DatabaseFilePath} {
     sqlite mydb $DatabaseFilePath
}

# Set up database tables
proc InitializeDatabase {} {
     variable LoggingTable
     variable DeletedTable
     variable TestTable

     set TableDict \
          [dict create \
               $LoggingTable { \
                    {id integer primary key} \
                    {undo text} \
                    {redo text} \
                    {type text} \
               } \
               $DeletedTable { \
                    {id integer primary key} \
                    {name text} \
                    {deleted_ids text} \
               } \
               $TestTable { \
                    {id integer primary key} \
                    {desc text} \
               } \
          ]

     dict for {TableName TableDef} $TableDict {
          if {[TableExists $TableName]} {
               mydb eval "DROP TABLE $TableName"
          }
          set sql "CREATE TABLE $TableName ([join $TableDef ","])"
          Debug $sql
          mydb eval $sql
     }
}

proc DeletedIdsEntryExistsFor {Table} {
     set sql "SELECT count(*) FROM $WayfareNS::DeletedTable WHERE name = '$Table'"
     if {[Q1 $sql] > 0} {
          return 1
     } else {
          return 0
     }
}

proc CreateDeletedIdsEntry {Table} {
     set sql "INSERT INTO $WayfareNS::DeletedTable (name, deleted_ids) VALUES ('$Table', '')"
     mydb eval $sql
}

proc AppendDeletedIds {Table IdList} {
     if {![DeletedIdsEntryExistsFor $Table]} {
          CreateDeletedIdsEntry $Table
          set CurrentList ""
     } else {
          set CurrentList [DeletedIdsFor $Table]
     }
     AppendIfNotAlready CurrentList $IdList
     set sql "UPDATE $WayfareNS::DeletedTable SET deleted_ids = '$CurrentList'"
     Debug $sql
     mydb eval $sql
}

proc RemoveDeletedIds {Table IdList} {
     set DeletedIdList [DeletedIdsFor $Table]
     FindAndRemoveMany DeletedIdList $IdList
     set sql "UPDATE $WayfareNS::DeletedTable SET deleted_ids = '$DeletedIdList'"
     mydb eval $sql
}

proc DeletedIdsFor {Table} {
     set sql "SELECT deleted_ids FROM $WayfareNS::DeletedTable WHERE name = '$Table'"
     return [Q1 $sql]
}

# Perform the transaction, including any logging. 
proc MakeLoggedSqlTransaction {Transaction} {
     # Extract the first word from the SQL statement.
     set FirstWord [regexp -inline {^\w+} $Transaction]
     # Handle logging differently for each type of transaction.
     switch -nocase $FirstWord {
          SELECT {
               if {[regexp -nocase {SELECT (.+) FROM (.+) WHERE (.+)} $Transaction All Columns Table WhereClause]} {
                    set Transaction "SELECT $Columns FROM $Table WHERE id NOT IN ([join [DeletedIdsFor $Table] ", "]) AND $WhereClause"
               } elseif {[regexp -nocase {SELECT (.+) FROM (.+)} $Transaction All Columns Table WhereClause]} {
                    set Transaction "SELECT $Columns FROM $Table WHERE id NOT IN ([join [DeletedIdsFor $Table] ", "])"
               } else {
                    puts "Unsupported SELECT format: $Transaction"
                    return -1
               }
          
               # Adjust so will only select entries that are visible.
               Debug $Transaction
               return [mydb eval $Transaction]
          }
          INSERT {
               Debug $Transaction
               # Extract the table name, target columns, and values.
               set Ok [regexp -nocase {INSERT INTO (.+) \((.+)\) VALUES \((.+)\)} $Transaction All Table Names Values]
               if {!$Ok} {
                    puts "Unsupported INSERT format: $Transaction"
                    return -1
               }
               # Make the transaction.
               mydb eval $Transaction
               # We need the ID for the new entry to be able to target it for undo / redo operations, so get it.
               set Id [LastId $Table]
               # To undo an insert, we add the ID to the DELETED table.
               set Undo "AppendDeletedIds $Table $Id"
               # To redo an insert, we remove the ID from the DELETED table.
               set Redo "RemoveDeletedIds $Table $Id"
               # Make the current undo ID now point to the new logging entry.
               IncrDbGlobal current_undo_id
               # Clear the last undo ID.
               SetDbGlobal last_undo_id -1
               # Make the new logging entry, possibly overwriting the previous at this ID.
               InsertOrOverwrite $WayfareNS::LoggingTable [GetDbGlobal current_undo_id int] [list undo "'$Undo'" redo "'$Redo'" type "'insert'"]
          }
          UPDATE {
               Debug "Update"
               # Does not yet have code to differentiate between types (e.g. text vs. integer).
               # Extract the table name, set clause, where clause
               set Ok [regexp {(\w+) SET (.+) WHERE (.+)} $Transaction All Table SetClause WhereClause]
               if {!$Ok} {
                    puts "Unsupported UPDATE format: $Transaction"
               }
               Debug "Table = $Table, SetClause = $SetClause, WhereClause = $WhereClause"
               # Ensure that we only perform the update on visible entries.
               # Add to the WHERE clause a condition to include only visible entries in the UPDATE.
               set DeletedIds [DeletedIdsFor $Table]
               Debug "DeletedIds = $DeletedIds"
               set Transaction [regsub { WHERE (.+)} $Transaction " WHERE id NOT IN ([join $DeletedIds ","]) AND \\1"]
               Debug "Transaction is now $Transaction"
               # Extract the update names and values.
               # Split the SetClause by commas and trim it.
               set List [CommaSeparatedStringToList $SetClause]
               Debug 1
               foreach Element $List {
                    lappend Names [lindex [split $Element " = "] 0]                    
               }               
               # Do a select to find out the IDs of the entries that will be affected and their current values.
               AppendIfNotAlready Names id
               Debug "Names is now $Names"
               set SelectList [join $Names ","]
               set sql "SELECT $SelectList FROM $Table WHERE $WhereClause"
               Debug "Finding entries that would match to save their values:\n$sql"
               set Results [Raise [mydb eval $sql] [llength $Names]]
               # Make a dict that holds the update info on a per-entry basis.
               set Dict [dict create]
               foreach Result $Results {
                    set Id [lindex $Result [lsearch $Names id]]
                    set TempDict [dict create]
                    for {set i 0} {$i < [llength $Names]} {incr i} {
                         set Name [lindex $Names $i]
                         set Value [lindex $Result $i]
                         Debug "$i: $Name --- $Value"
                         dict set TempDict $Name $Value
                    }
                    dict set Dict $Id $TempDict
               }
               # Store that dict as the undo info.         
               set Undo "[set Table]`[set Dict]"
               # The redo is simply running the update again.
               set Redo $Transaction
               # Perform the transaction.
               mydb eval $Transaction
               # Clear the last undo ID.
               SetDbGlobal last_undo_id -1
               # Increment the current undo ID to point to the new logging entry.
               IncrDbGlobal current_undo_id
               # Make the log entry, possibly overwriting a previous entry at this ID.
               InsertOrOverwrite $WayfareNS::LoggingTable [GetDbGlobal current_undo_id int] [list undo "\"$Undo\"" redo "\"$Redo\"" type "'update'"]
          }
          DELETE {
               # Extract out the table name and the where clause.
               # Not actually going to delete the entry but rather change its visibility.
               if {[regexp -nocase {DELETE FROM (\w+)$} $Transaction All Table]} {
                    set sql "SELECT id FROM $Table"
               } elseif {[regexp -nocase {DELETE FROM (\w+) WHERE (.+)$} $Transaction All Table WhereClause]} {
                    set sql "SELECT id FROM $Table WHERE $WhereClause"
               } else {
                    puts "Unsupported DELETE format: $Transaction"
               }
               Debug "Delete"
               Debug "Finding what would delete:\n$sql"
               set List [mydb eval $sql]
               Debug "Would have deleted: $List"
               AppendDeletedIds $Table $List
               set Undo "RemoveDeletedIds $Table $List"
               set Redo "AppendDeletedIds $Table $List"
               # Clear the last undo ID.
               SetDbGlobal last_undo_id -1               
               IncrDbGlobal current_undo_id
               # Make the log entry, possibly overwriting a previous entry at this ID.
               InsertOrOverwrite $WayfareNS::LoggingTable [GetDbGlobal current_undo_id int] [list undo "\"$Undo\"" redo "\"$Redo\"" type "'delete'"]
          }
     }
}

# Undo the top transaction. 
proc Undo {} {
     # Get the current undo id.
     set CurrentUndoId [CurrentUndoId]
     if {$CurrentUndoId == 0} {
          # Being at zero means nothing to undo.
          Debug "Nothing to undo"
          return 0
     }
     
     # Get the undo text.
     set sql "SELECT undo, type FROM $WayfareNS::LoggingTable WHERE id = $CurrentUndoId"
     set Results [mydb eval $sql]
     set UndoText [lindex $Results 0]
     set UndoType [lindex $Results 1]
     # Perform the undo.
     switch -nocase $UndoType {
          update {
               # Update undo requires special code to process the stored dict and perform the update undo on a per-entry basis.
               Debug "Got UndoText $UndoText"
               set Split [split $UndoText "`"]
               set Table [lindex $Split 0]
               set Dict [lindex $Split 1]
               Debug "Got Table $Table"
               Debug "Got Dict $Dict"
               dict for {Id Entry} $Dict {
                    set SetClauseList {}
                    Debug "$Id | $Entry"
                    dict for {Key Value} $Entry {
                         if {[string is integer $Value]} {
                              lappend SetClauseList "$Key = $Value"
                         } else {
                              lappend SetClauseList "$Key = '$Value'"
                         }
                    }
                    set SetClause [join $SetClauseList ", "]
                    set sql "UPDATE $Table SET $SetClause WHERE id = $Id"
                    mydb eval $sql
               }          
          }
          default {
               Debug "Undoing -- $UndoText"
               eval $UndoText
          }
     }
     # Make the last undo ID equal to the current undo ID.
     SetDbGlobal last_undo_id $CurrentUndoId
     # Move the current undo ID backward by one.
     DecrDbGlobal current_undo_id
     
     return 1
}

# Redo the top transaction. 
proc Redo {} {
     Debug "Redo"
     # Get the last undo ID.
     set LastUndoId [GetDbGlobal last_undo_id int]
     if {$LastUndoId == -1} {
          Debug "Nothing to redo"
          return 0
     }
     # Get the redo text.
     set sql "SELECT redo, type FROM $WayfareNS::LoggingTable WHERE id = $LastUndoId"
     Debug $sql
     set Results [mydb eval $sql]
     set RedoText [lindex $Results 0]
     set RedoType [lindex $Results 1]
     # Perform the redo.
     Debug "Redoing -- $RedoText"
     switch -nocase $RedoType {
          update {
               mydb eval $RedoText
          }
          default {
               eval $RedoText
          }
     }
     # Make the current undo ID equal to the last undo ID.
     SetDbGlobal current_undo_id $LastUndoId
     # Check to see if there are no more entries to redo (we are at the end).
     # If so, clear the last undo ID index.
     # If not, increment the last undo ID index.
     if {[Q1 "SELECT count(*) FROM $WayfareNS::LoggingTable WHERE id = [incr LastUndoId]"] == 0} {
          SetDbGlobal last_undo_id -1
     } else {
          IncrDbGlobal last_undo_id
     }
     return 1
}

# Clear the tables and reset the variables. 
proc Clear {} {
     Debug "Clear"
     # Delete all entries from the logging table.
     set sql "DELETE FROM $WayfareNS::LoggingTable"
     Debug $sql
     mydb eval $sql
     # Reset the current undo ID.
     SetDbGlobal current_undo_id 0
     SetDbGlobal last_undo_id -1
     # Make all deletes be permanent
     CleanAllTables
}

# Convert temporary deletes into permanent deletes. 
proc CleanTable {TableName} {
     Debug "Cleaning $TableName"
     set DeletedIds [DeletedIdsFor $TableName]     
     set sql "DELETE FROM [set TableName] WHERE id IN ([join $DeletedIds ","])"
     Debug $sql
     mydb eval $sql
     RemoveDeletedIds $TableName $DeletedIds     
}

# Convert temporary deletes into permanent deletes for all tables.
proc CleanAllTables {} {
     Debug "Cleaning all tables"
     set sql "SELECT name FROM $WayfareNS::DeletedTable"
     Debug $sql
     set Results [mydb eval $sql]
     Debug "Table names are [join $Results ", "]"
     foreach Result $Results {
          CleanTable $Result
     }
}

# Perform a logged transaction if logging is on, otherwise do a normal transaction.
proc Xact1 {Transaction} {
     Debug $Transaction
     if {$WayfareNS::Off} {
          return [mydb eval $Transaction]
     } else {
          return [WayfareNS::MakeLoggedSqlTransaction $Transaction]
     }
}

# Show the entries in the logging table.
proc ShowLoggingTable {} {
     set sql "SELECT id, undo, redo, type FROM $WayfareNS::LoggingTable"
     set Results [Raise [mydb eval $sql] 4]
     PrintList $Results
}

# Show the entries in the deleted ids table.
proc ShowDeletedIdsTable {} {
     set sql "SELECT id, name, deleted_ids FROM $WayfareNS::DeletedTable"
     set Results [Raise [mydb eval $sql] 3]
     PrintList $Results
}

# Get the current undo id.
proc CurrentUndoId {} {
     GetDbGlobal current_undo_id int
}

# Get the last undo id.
proc LastUndoId {} {
     GetDbGlobal last_undo_id int
}

# Show the test, logging, deleted ids table and the current/last undo ids.
proc ShowAll {} {
     puts "Test Table"
     TestNS::Show
     puts "Logging Table"
     ShowLoggingTable
     puts "Deleted Ids Table"
     ShowDeletedIdsTable
     puts "Current Undo Id : [CurrentUndoId]"
     puts "Last Undo Id : [LastUndoId]"
}

# Delete everything from all Wayfare tables and reset the undo ids.
proc ResetAll {} {
     mydb eval "DELETE FROM $WayfareNS::TestTable"
     mydb eval "DELETE FROM $WayfareNS::LoggingTable"
     mydb eval "DELETE FROM $WayfareNS::DeletedTable"
     SetDbGlobal current_undo_id 0
     SetDbGlobal last_undo_id -1
}

}
