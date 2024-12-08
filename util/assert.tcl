

namespace eval ::assert {

    namespace export *
    
    proc assert {cond {msg "!!! Assestion error"}} {
	set cond [uplevel 1 [list expr $cond]]
	if {!$cond} {
	    return -code error $msg
	}
    }

    proc assert-eq {v1 v2 {msg "Assertation error"}} {
	assert {$v1 == $v2} "!!! expect $v1 == $v2 - $msg"
    }

    proc assert-ne {v1 v2 {msg "Assertation error"}} {
	assert {$v1 != $v2} "!!! expect $v1 != $v2 - $msg"
    }

    proc assert-empty {v {msg "Assertion error"}} {
	assert { $v == ""} "!!! expect <empty> == $v - $msg"
    }

    proc assert-non-empty {v {msg "Assertion error"}} {
	assert { $v != ""} "!!! expect <non empty> != <empty> - $msg"
    }
    
}
