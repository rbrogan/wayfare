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
     # Handle logging differently for each type of transaction.
     switch -nocase $FirstWord {
          SELECT {
               # Adjust so will only select entries that are visible.
          }
          INSERT {
               # Extract the table name, target columns, and values.
               # Modify the target columns and values so that it will include the visibility column and make the new entry be visible.
               # Make the transaction.
               # We need the ID for the new entry to be able to target it for undo / redo operations, so get it.
               # Undoing an insert is not a delete but rather setting visibility to 0.
               # Likewise redoing an insert is not an insert but rather setting visibility back to 1.
               # Make the current undo ID now point to the new logging entry.
               # Clear the last undo ID.
               # Make the new logging entry, possibly overwriting the previous at this ID.
          }
          UPDATE {
               # Does not yet have code to differentiate between types.
               # Ensure that we only perform the update on visible entries.
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
               # !!! We interpret the meaning here in the simplest way. We are not targeting specific entries but rather wahtever is hit by the WHERE clause.
               # Alternatively, we could choose to only use the WHERE clause in the original transaction and save those IDs and have the undo / redo apply only to them.
               # Clear the last undo ID.
               # Make the log entry, possibly overwriting a previous entry at this ID.
          }
     }
}

# Undo the top transaction. 
proc Undo {} {
     # Get the current undo ID.
     # Get the undo text.
     # Perform the undo.
     # Make the last undo ID equal to the current undo ID.
     # Move the current undo ID backward by one.
}

# Redo the top transaction. 
proc Redo {} {
     # Get the last undo ID.
     # Get the redo text.
     # Perform the redo.
     # Make the current undo ID equal to the last undo ID.
     # Check to see if there are no more entries to redo (we are at the end).
     # If not, increment the last undo ID index.
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
