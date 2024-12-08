package provide tfast 1.0

package require logger

set dir [file dirname [file normalize [info script]]]

source [file join $dir util lists.tcl]
source [file join $dir util dicts.tcl]
source [file join $dir util props.tcl]
source [file join $dir util assert.tcl]
source [file join $dir http mimes.tcl]
source [file join $dir http codes.tcl]
source [file join $dir http request.tcl]
source [file join $dir http response.tcl]
source [file join $dir router route.tcl]
source [file join $dir router router.tcl]
source [file join $dir http http_server.tcl]

# http://www.tcl.tk/man/tcl/TclCmd/prefix.htm

namespace import ::tfast::http::*
namespace import ::dicts::*
namespace import ::lists::*
namespace import ::tfast::router::*

namespace eval ::tfast {

    namespace export tfast render

    variable log
    variable ServerSocket_fd

    set log [logger::init tfast]


    # Return true if list of values contains any
    # item of list args, orelse false
    # @param values keyvallist
    # @param args list of keys to search
    proc any_option {values args} {
	foreach key $args {
	    if {[lsearch $values $key] > -1} {
		return true
	    }
	}
	return false
    }

    # Return value of key {name}, orelse default valoe of {def}
    # @param values keyvallist
    # @param name name to find
    # @param default value
    proc get_option {values key {def ""}} {
	set i [lsearch $values $key]
	if {$i > -1} {
	    incr i
	    return [lindex $values $i]
	}
	return $def
    }

    # Return list of values by key
    # @param values keyvallist
    # @param key key to find
    # @param default value
    # @param x n of items to get
    # eg. given a list {-status 200 {req resp {}}}
    # call get_option_x_args with key = -status and x = 2
    # will results in {200  {req resp {}}}
    proc get_option_list_with_x_args {values key {x 1}} {
	set indexes [lsearch -all $values $key]
	set results {}
	foreach i $indexes {

	    if {$x == 1} {
		incr i
		lappend results [lindex $values $i]
	    } else {
		set item {}
		for {set j 0} {$j < $x} {incr j} {
		    incr i
		    lappend item [lindex $values $i]
		}
		lappend results $item
	    }
	}
	return $results
    }

    # Return list of values by key
    # @param values keyvallist
    # @param key key to find
    # @param default value
    # @return {code_type {proc|lambda} handler {} action_type {action|middleware}}
    proc get_option_list {values key} {
	get_option_list_with_x_args $values $key
    }
    
    proc get_code_info {code} {

	set nargs -1
	
	if {[info procs $code] != ""} {
	    set code_type proc
	    set nargs [info args $code]
	} else {
	    set code_type lambda

	    if {[regexp {\s*(\w+)\s+(\w+)\s+({.*})} $code -> x y z]} {
		# find by {x y {}} and fix lambda sintax
		set code "{$x $y} $z"
		set nargs 2
	    } elseif {[regexp {\s*{\s*\w+\s+\w+\s*}\s+{.*?}\s*} $code]} {
		# find by {{x y} {}}
		set nargs 2
	    } elseif {[regexp {\s*\w+\s+{.*?}\s*} $code] || [regexp {\s*{\s*\w+\s*}\s*{.*?}\s*} $code]} {
		# find by {it {}} or {{it} {}}
		set nargs 1; #[expr {[llength $code] - 1}]
	    }
	}

	if {$nargs == 2} {
	    dict create code_type $code_type handler $code nargs $nargs
	} elseif {$nargs == 1} {
	    dict create code_type $code_type handler $code nargs $nargs
	} else {
	    return -code error "invalid handler args $nargs: $code"
	}
    }

    proc any {path args} {
	add_route any $path {*}$args
    }
    
    proc get {path args} {
	add_route get $path {*}$args
    }

    proc head {path args} {
	add_route head $path {*}$args
    }
    
    proc options {path args} {
	add_route options $path {*}$args
    }

    proc post {path args} {
	add_route post $path {*}$args
    }

    proc put {path args} {
	add_route put $path {*}$args
    }

    proc delete {path args} {
	add_route delete $path {*}$args
    }

    proc patch {path args} {
	add_route patch $path {*}$args
    }

    proc cmd_route {method args} {
	add_route $method [lindex $args 0] {*}[lrange $args 1 end]
    }

    #
    # @param cmd match
    # @param args to match use: method path
    #
    #
    proc tfast {cmd args} {
	switch $cmd {
	    get - head - options - post - put - delete - patch - any {
		cmd_route $cmd {*}$args
	    }
	    enter - leave {
		lassign $args path handler
		add_middleware $path $cmd any $handler
	    }
	    recover {
		lassign $args path handle
		add_recover_interceptor $path $handler
	    }
	    cleanup {
		router_cleanup
	    }
	    route {
		lassign $args type method path
		switch $type {
		    match {
			route_match $method $path			
		    }
		    default {
			return -code error "invalid option $type. use match <method> <path>"
		    }
		}
	    }
	    print {
		foreach it $args {
		    switch -- $it {
			-routes {
			    print_routes
			}
			-interceptors {
			    print_interceptors
			}
			-middlewares {
			    print_middlewares
			}
			default {
			    return -code error "invalid option $v. use -routes | -interceptors | -middlewares"
			}
		    }
		}
	    }
	    ns {
		set path [lindex $args 0]
		set route_args [lrange $args 1 end]

		if {[any_option $args -enter -leave -recover -status -method]} {
		    # use add middleware options to ns
		    add_ns_middleware $path {*}$route_args
		    return
		}

		# ns dsl
		foreach {type rpath handler} [lindex $route_args 0] {

		    set rpath $path$rpath

		    switch $type {
			enter - leave {
			    add_middleware $rpath $type any $handler
			}
			recover {
			    add_recover_interceptor $rpath $handler
			}
			get - head - options - post - put - delete - patch - any {
			    tfast $type $rpath $handler
			}
			ns {
			    tfast ns $rpath $handler
			}
			default {
			    add_others_types $type $rpath $handler
			}
		    }
		}
	    }
	    serve {
		set host [dictge $args -host localhost]
		set port [dictget $args -port 3000]
		set workers [dictget $args -workers 1]
		serve $host $port $workers
	    }
	    default {
		lassign $args path handler
		add_others_types $cmd $path $handler
	    }
	}
    }

    #@param type route type get post * get,post get|post 500 etc..
    #@param poth
    #@param handler lambda or proc
    proc add_others_types {type path handler} {

	set codes [get_codes]
	
	if {[dict exists $codes $type]} {
	    add_status_code_interceptor $path $type $handler
	    return
	}

	# is going here, type is unknown so should be verb,verb etc..
	set methods [get_methods $type]
	if {[llength $methods] < 2} {	    
	    return -code error "unknown NS handler type: $type"
	}
	
	foreach it $methods {
	    tfast $it $path $handler
	}

    }

    proc get_methods {method} {
	if {[string match *,* $method]} {
	    split $method ,
	} elseif {[string match *\|* $method]} {
	    split $method |
	} elseif {$method == "*" || $method == ""} {
	  list any  
	} else {
	    list $method
	}
    }
    
    # @param path
    # @param args {-enter {} -leave {} -recover {} -method {} -status <code> {}}
    proc add_ns_middleware {path args} {
	set enter_list [get_option_list $args -enter]
	set leave_list [get_option_list $args -leave]
	set recover_list [get_option_list $args -recover]
	set status_list [get_option_list_with_x_args $args -status 2]
	set methods [get_methods [get_option $args -method]]

	foreach it $enter_list {
	    set code_info [get_code_info $it]
	    set code_type [dict get $code_info code_type]
	    set handler [dict get $code_info handler]
	    if {[dict get $code_info nargs] != 1} {
		return -code error "invalid anter middleware: $handler"
	    }
	    foreach mtd $methods {
		add_middleware $path enter $mtd [list $code_type $handler]
	    }
	}

	foreach it $leave_list {
	    set code_info [get_code_info $it]
	    set code_type [dict get $code_info code_type]
	    set handler [dict get $code_info handler]
	    if {[dict get $code_info nargs] != 2} {
		return -code error "invalid leave middleware: $handler"
	    }
	    foreach mtd $methods {
		add_middleware $path leave $mtd [list $code_type $handler]
	    }
	}

	foreach it $recover_list {
	    set code_info [get_code_info $it]
	    set code_type [dict get $code_info code_type]
	    set handler [dict get $code_info handler]
	    if {[dict get $code_info nargs] != 2} {
		return -code error "invalid recover: $handler"
	    }
	    add_recover_interceptor $path [list $code_type $handler]
	}
	foreach it $status_list {
	    lassign $it status code
	    set code_info [get_code_info $code]
	    set code_type [dict get $code_info code_type]
	    set handler [dict get $code_info handler]
	    if {[dict get $code_info nargs] != 2} {
		return -code error "invalid interceptor: $handler"
	    }
	    add_status_code_interceptor $path $status [list $code_type $handler]
	}
    }

    #@param path
    #@param type enter,leave
    #@method verb
    #@code {req resp next {}}
    proc add_middleware {path type method code} {
	register_ns_middleware $path $type [list $method $code] 
    }

    #@param path
    #@param code {req resp {}}
    proc add_recover_interceptor {path code} {
	register_ns_recover_interceptor $path $code
    }

    #@param path
    #@param status http status code
    #@param code {req resp {}}
    proc add_status_code_interceptor {path status code} {
	register_ns_status_code_interceptor $path $status $code
    }
    
    proc add_route {method path args} {

	set codes [::lists::map $args {it {::tfast::get_code_info $it}}]
	set enter_list [::lists::filter $codes {it {expr {[dict get $it nargs] == 1}}}]
	set handler [::lists::last $enter_list]
	set enter_list [::lists::butlast $enter_list]
	set leave_list [::lists::filter $codes {it {expr {[dict get $it nargs] == 2}}}]

	if {$handler == ""} {
	    return -code error "invalid action"
	}

	set actions {}

	foreach it $enter_list {
	    lappend actions [dict create \
				 code_type [dict get $it code_type] \
				 handler [dict get $it handler] \
				 action_type enter]
	}

	lappend actions [dict create \
			     code_type [dict get $handler code_type] \
			     handler [dict get $handler handler] \
			     action_type action]

	foreach it $leave_list {
	    lappend actions [dict create \
				 code_type [dict get $it code_type] \
				 handler [dict get $it handler] \
				 action_type leave]
	}

	register_route $method $path $actions
    }

    proc serve {host port workers} {

	variable log
	variable ServerSocket_fd

	if {$workers > 1} {
	    worker_init $workers
	    set socket [socket -server worker_accept $port]  
	} else {
	    http_init {*}$args
	    set socket [socket -server http_accept $port]  
	}

	${log}::info "http server started on http://localhost:$port"

	set ServerSocket_fd $socket

	#websocket_init $socket

	vwait forever	
    }

    proc render {args} {
	Response new {*}$args
    }
}
