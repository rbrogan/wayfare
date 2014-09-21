package provide wayfare 2.0
package require gen

namespace eval TestNS {

proc Create {Desc} {
     WayfareNS::Xact1 "INSERT INTO $WayfareNS::TestTable (desc) VALUES ('$Desc')"     
}

proc Delete {Target} {
     WayfareNS::Xact1 "DELETE FROM $WayfareNS::TestTable WHERE id = [IdFor $Target]"
}

proc IdFor {Target} {
     if {[string is integer $Target]} {
          set Id $Target
     } else {
          set Id [lindex [WayfareNS::Xact1 "SELECT id FROM $WayfareNS::TestTable WHERE desc = '$Target'"] 0]
     }
     return $Id
}

proc SetDesc {Target Desc} {
     set sql "UPDATE $WayfareNS::TestTable SET desc = '$Desc' WHERE id = [IdFor $Target]"
     WayfareNS::Xact1 $sql
}

proc Show {} {
     PrintList [Raise [WayfareNS::Xact1 "SELECT * FROM $WayfareNS::TestTable"] 2]
}

}
