
package require TclOO

namespace eval ::props {
    
    namespace export Props
	
    oo::class create Props {
	variable MyProps allowed_props PermitsNew
	# Contruct new Props
	#
	# @param args list of allowed props
	# <code>
	# oo:define MyClass {
	#	constructor {
	#		next prop1 prop2 prop3
	#   }	
	# }
	# Uuse -permits-new to permitir add new props after object created. The default
	# behavior is throw error when props not found
	# </code>
	constructor {args} {
	    my set_allowed_props {*}$args
	}

	# create list of allowed props
	method set_allowed_props {args} {
	    my variable MyProps PermitsNew allowed_props
	    set MyProps [dict create]
	    set allowed_props $args
	    set PermitsNew [expr {[llength $args] == 0}]
	    foreach prop $args {

		if {$prop == "-permits-new"} {
		    set PermitsNew true
		    continue
		}

		dict set MyProps $prop {}
	    }
	}		

	# Get or set prop
	# <code>
	# set name [$obj prop name]
	# $obj prop name {John Doo}
	# </code>
	method prop {args} {
	    my variable MyProps PermitsNew allowed_props
	    set argc [llength $args]

	    if {$argc == 0 || $argc > 2} {
		return -code error "use prop set or get to [info object class [self]]"
	    }
	    
	    set prop_name [lindex $args 0]
	    
	    if {!$PermitsNew && [lsearch -exact $allowed_props $prop_name] == -1} {
		return -code error "prop $prop_name not allowed to [info object class [self]]"
	    } 
	    
	    if {$argc == 2} {
		dict set MyProps $prop_name [lindex $args 1]
	    }

	    dict get $MyProps $prop_name
	}

	# Get prop or default value
	# <code>
	# set name [$obj propdef name {John Doo}]
	# </code>
	method propdef {name def} {
	    my variable MyProps
	    if {[my present $name]} {
		my prop $name
	    } else {
		return $def
	    }
	}


	# Map prop value to apply lambda result
	# <code>
	# set i [$obj propmap counter {i { expr {i + 1} }}]
	# </code>		
	method propmap {name body} {
	    apply $body [my prop $name]
	}

	#
	# @param cmd <len, map, filter, filtermap, search>
	method proplist {cmd propname args} {
	    set val [my prop $propname]
	    switch $cmd {
		len {
		    llength $val
		}
		search {
		    lsearch $val {*}$args
		}
		map {
		    lassign $args lambda 
		    set results {}
		    foreach it $val {
			lappend results [apply $lambda $it]
		    }
		    return $results
		}
		filter {
		    lassign $args lambda 
		    set results {}
		    foreach it $val {
			if {[apply $lambda $it]} {
			    lappend results $it
			}
		    }
		    return $results
		}
		filtermap {
		    lassign $args filter map
		    
		    set results {}
		    set map 
		    foreach it $val {
			if {[apply $filter $it]} {
			    lappend results [apply $map $it]
			}
		    }
		    return $results			
		}
	    }
	}

	method propdict {cmd propname args} {
	    set val [my prop $propname]
	    switch $cmd {
		exists {
		    lassign $args key
		    dict exists $val $key
		}
		get {
		    lassign $args key def
		    if {[dict exists $val $key]} {
			dict get $val $key
		    } else {
			return $def
		    }
		}
		size {
		    dict size $val
		}
	    }
	}

	# Change prop value to apply lambda result
	# <code>
	# set i [$obj propmap counter {i { expr {i + 1} }}]
	# </code>		
	method propapply {name body} {
	    my prop $name [my propmap $name $body]
	}

	method propmerge {name values} {
	    set val [my propdef $name {}]
	    my prop $name [list {*}$val {*}$values]
	}

	# Set props from dict
	method props {args} {
	    my variable MyProps PermitsNew allowed_props

	    if {[llength $args] == 0} {
		return $MyProps
	    }
	    
	    foreach {k v} $args {
		if {!$PermitsNew && [lsearch -exact $allowed_props $k] == -1} {
		    return -code error "prop $k not allowed to [info object class [self]]"
		}
		dict set MyProps $k $v
	    }
	    return [self]
	}

	method update {args} {
	    my props {*}$args 
	}

	method updatemap {args} {
	    set body [::lists::last $args]
	    set keys [::lists::butlast $args]
	    foreach k $keys {
		my prop $k [apply $body [my prop $k]]
	    }
	    return [self]
	}

	# Get value from boolean prop
	method bool {name} {
	    set val [my prop $name]
	    expr {$val == 1 || $val == true}
	}

	# check prop was defined
	method present {name} {
	    expr {[my prop $name] != ""}
	}

	method to_dict {} {
	    my variable MyProps
	    set d [dict create]
	    dict for {k v} $MyProps {
		dict set d $k $v
	    }
	    return $d
	}

	method from_dict {d} {
	    my variable allowed_props
	    foreach k $allowed_props {
		if {[dict exists $d $k]} {
		    my prop $k [dict get $d $k]
		}
	    }
	    return [self]		
	}
    }
}
