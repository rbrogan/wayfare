package provide wayfare 2.0
package require Tclx
package require gen

namespace eval WayfareNS {

variable Off 0
variable DebugOn 0

proc Debug {Message} {
     if {$DebugOn != 0} {
          puts $Message
     }
}

# Configures which sqlite database to use. 
proc ConfigDatabase {DatabaseFilePath} {
     sqlite mydb $DatabaseFilePath
}

# Set up database tables
proc InitializeDatabase {} {
     set TableDict \
          [dict create \
               logging { \
                    {id integer primary key} \
                    {groupid integer} \
                    {undo text} \
                    {redo text} \
                    {type text} \
               } \
               logging_relations { \
                    {id integer primary key} \
                    {leftid integer} \
                    {rightid integer} \
                    {value text} \
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

# Increment the CurrentGroupId variable by one. 
proc IncrCurrentGroupId {} {
}

# Decrement the CurrentGroupId variable by one. 
proc DecrCurrentGroupId {} {
}

# Set the CurrentGroupId variable to the given value. 
proc SetCurrentGroupId {} {
}

# Get the value of the CurrentGroupId variable. 
proc CurrentGroupId {} {
}

# Create a new transaction group.
proc CreateGroup {{ParentGroupId 0}} {
     # Increment the last group id created from the globals table by 1,
     # to create a new logging group id.
     
}

# Delete the given transaction group and all members. 
proc DeleteGroup {GroupId} {
     # Delete child groups of the target group.
     # Delete the target group.
}

# Perform the transaction, including any logging. 
proc MakeLoggedSqlTransaction {Transaction {GroupId 0}} {
     # Extract the first word from the SQL statement.
     set FirstWord [regexp -inline {^\w+} $Transaction]
     # Handle logging differently for each type of transaction.
     switch -nocase $FirstWord {
          SELECT {
               # Adjust so will only select entries that are visible.
               if {[regexp "WHERE" $Transaction]} {
                    # Add to the WHERE clause a condition that the visibility be != 0.
                    # Pick out the WHERE clause itself.
                    # Append to it the addition.
                    # Reconstitute the statement.
               } else {
                    # Simple enough, add a WHERE clause with the visibility != 0.
                    set Transaction "$Transaction WHERE visibility != 0"                    
               }
               Debug $Transaction
               return [mydb eval $Transaction]
          }
          INSERT {
               # Extract the table name, target columns, and values.
               regexp -nocase {INSERT INTO (.+) \((.+)\) VALUES \((.+)\)} $Transaction All Table Names Values
               # Modify the target columns and values so that it will include the visibility column and make the new entry be visible.
               set Names "$Names, visibility"
               set Values "$Values, 1"
               set Transaction "INSERT INTO $Table ($Names) VALUES ($Values)"
               # Make the transaction.
               mydb eval $Transaction
               # We need the ID for the new entry to be able to target it for undo / redo operations, so get it.
               set Id [LastId $Table]
               # Undoing an insert is not a delete but rather setting visibility to 0.
               set Undo "UPDATE $Table SET visibility = 0 WHERE id = $Id"
               # Likewise redoing an insert is not an insert but rather setting visibility back to 1.
               set Redo "UPDATE $Table SET visibility = 1 WHERE id = $Id`[EscapedSqliteVersion [set Transaction]]"
               # Make the current undo ID now point to the new logging entry.
               IncrDbGlobal current_undo_id
               # Clear the last undo ID.
               SetDbGlobal last_undo_id -1
               # Make the new logging entry, possibly overwriting the previous at this ID.
               InsertOrOverwrite logging [GetDbGlobal current_undo_id int] [list groupid $GroupId undo "'$Undo'" redo "'$Redo'" type "'insert'"]
          }
          UPDATE {
               # Does not yet have code to differentiate between types (e.g. text vs. integer).
               # Extract the table name, set clause, where clause
               regexp {(\w+) SET (.+) WHERE (.+)} $Transaction All Table SetClause WhereClause
               # Ensure that we only perform the update on visible entries.
               # Add to the WHERE clause a condition to include only visible entries in the UPDATE.
               set Transaction [regsub { WHERE (.+)} $Transaction " WHERE visibility = 1 AND \\1"]
               # Extract the update names and values.
               # Split the SetClause by commas and trim it.
               # Do a select to find out the IDs of the entries that will be affected and their current values.
               # Make a dict that holds the update info on a per-entry basis.
               # Store that dict as the undo info.
               # The redo is simply running the update again.
               # Escape any single quotes.
               # Perform the transaction.
               # Clear the last undo ID.
               # Increment the current undo ID to point to the new logging entry.
               # Make the log entry, possibly overwriting a previous entry at this ID.
          }
          DELETE {
               # Extract out the table name and the where clause.
               # Not actually going to delete the entry but rather change its visibility.
               if {[regexp -nocase {DELETE FROM (\w+)$} $Transaction All Table]} {
               } elseif {[regexp -nocase {DELETE FROM (\w+) WHERE (.+)$} $Transaction All Table WhereClause]} {
               }
               
               # !!! We interpret the meaning here in the simplest way. We are not targeting specific entries but rather wahtever is hit by the WHERE clause.
               # Alternatively, we could choose to only use the WHERE clause in the original transaction and save those IDs and have the undo / redo apply only to them.
               set sql "UPDATE $Table SET visibility = 0 WHERE $WhereClause"
               mydb eval $sql
               set Undo "UPDATE $Table SET visibility = 0 WHERE $WhereClause"
               set Redo $sql
               # Clear the last undo ID.
               SetDbGlobal last_undo_id -1               
               # Make the log entry, possibly overwriting a previous entry at this ID.
               IncrDbGlobal current_undo_id
               InsertOrOverwrite logging [GetDbGlobal current_undo_id int] [list groupid $GroupId undo "'$Undo'" redo "'$Redo'" type "'delete'"]
          }
     }
}

# Undo the top transaction. 
proc Undo {} {
     # Get the current undo id.
     set CurrentUndoId [CurrentUndoId]
     if {$CurrentUndoId == 0} {
          # Being at zero means nothing to undo.
          return 0
     }
     
     # Get the undo text.
     set sql "SELECT undo, type FROM logging WHERE id = $CurrentUndoId"
     set UndoText ""; set UndoType ""
     MultiSet {UndoText UndoType} [mydb eval $sql]
     # Perform the undo.
     if {![string equal $UndoType "update"]} {
          mydb eval $UndoText
     } else {
          # Update undo requires special code to process the stored dict and perform the update undo on a per-entry basis.
          set Table ""; set Dict ""
          MultiSet {Table Dict} [split $UndoText "`"]
          dict for {Id Entry} $Dict {
               set SetClauseList {}
               dict for {Key Value} $Entry {
                    if {[string is integer $Value]} {
                         lappend SetClauseList "$Key = $Value"
                    } else {
                         lappend SetClauseList "$Key = '$Value'"
                    }
               }
               set SetClauseList [join $SetClauseList ", "]
               set sql "UPDATE $Table SET $SetClause WHERE id = $Id"
               mydb eval $sql
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
     # Get the last undo ID.
     set LastUndoId [GetDbGlobal last_undo_id int]
     if {$LastUndoId == -1} {
          return 0
     }
     # Get the redo text.
     set sql "SELECT redo, type FROM logging WHERE type = $LastUndoId"
     set RedoText ""; set RedoType ""
     MultiSet {RedoText RedoType} [mydb eval $sql]
     # Perform the redo.
     switch $RedoType {
          "insert" {
               set RedoType1Text ""; set RedoType2Text
               MultiSet {RedoType1Text RedoType2Text} [split $RedoText "`"]
               mydb eval $RedoType1Text
          }
          default {
               mydb eval $RedoText
          }
     }
     # Make the current undo ID equal to the last undo ID.
     SetDbGlobal current_undo_id $LastUndoId
     # Check to see if there are no more entries to redo (we are at the end).
     # If so, clear the last undo ID index.
     # If not, increment the last undo ID index.
     if {[Q1 "SELECT count(*) FROM logging WHERE id = [incr LastUndoId]"] == 0} {
          SetDbGlobal last_undo_id -1
     } else {
          IncrDbGlobal last_undo_id
     }
     return 1
}

# Clear the tables and reset the variables. 
proc Clear {} {
     # Delete all entries from the logging table.
     # Delete all entries from the group relations table.
     # Reset the current undo ID.
     # Reset the last undo ID.
}

# Convert temporary deletes into permanent deletes. 
proc CleanTable {TableName} {
     # Delete all invisible entries from the given table.
}

}
