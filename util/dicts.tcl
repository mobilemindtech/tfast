
namespace eval ::dicts {

    namespace export dictget dictmap dicts

    # @param d dict
    # @param list keys, the last is default value
    proc get {d args} {
	set last [lindex $args end]
	set first [lrange $args 0 end-1]
	if {[dict exists $d {*}$first]} {
	    dict get $d {*}$first
	} else {
	    return $last
	}
    }

    proc map {d key lambda} {
	if {[dict exists $d $key]} {
	    apply $lambda [dict get $d $key]
	}
	return {}
    }

    proc keyslist {d args} {
	set values {}
	foreach k $args {
	    lappend values [dict get $d $k]
	}
	return $values
    }

    proc dicts {cmd d args} {
	switch $cmd {
	    get {
		get $d {*}$args
	    }
	    map {
		map $d {*}$args
	    }
	    list {
		keyslist $d {*}$args
	    }
	    default {
		return -code error "invalid command $cmd"
	    }
	}
    }

    interp alias {} dictmap {} map
    interp alias {} dictget {} get
}
