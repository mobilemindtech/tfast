#!/bin/tclsh

package require logger 0.3
package require TclOO

namespace import ::dicts::*
namespace import ::lists::*

namespace eval ::tfast::router {

    namespace export \
	router_cleanup \
	register_route \
	register_ns_middleware \
	register_ns_recover_interceptor \
	register_ns_status_code_interceptor \
	route_match \
	print_routes \
	print_interceptors \
	print_middlewares \
	build_config_routes \
	build_scaffold_routes \
	get_routes \
	set_routes \
	find_recovers \
	find_interceptors
    
    
    variable log
    variable routes
    variable NsMiddlewareEnterList
    variable NsMiddlewareLeaveList
    variable NsRecoverInterceptorList
    variable NsStatusCodeInterceptorList
    
    set log [logger::init tfast::router]
    set routes {}
    set NsMiddlewareEnterList {}
    set NsMiddlewareLeaveList {}
    set NsRecoverInterceptorList {}
    set NsStatusCodeInterceptorList {}
    
    proc router_cleanup {} {
	variable routes
	variable NsMiddlewareEnterList
	variable NsMiddlewareLeaveList
	variable NsRecoverInterceptorList
	variable NsStatusCodeInterceptorList

	set routes {}
	set NsMiddlewareLeaveList {}
	set NsMiddlewareEnterList {}
	set NsRecoverInterceptorList {}
	set NsStatusCodeInterceptorList {}
    }
    
    #@param method
    #@param path
    #@param code_actions list of  {code_type {lambda,proc} action_type {middleware,action}, handler {code,proc}}
    proc register_route {method path actions} {

	variable routes
	
	set action false
	set handler {}
	set handler_type {}
	set enter_list [::lists::filter $actions {it {expr {[dict get $it action_type] == "enter"}}}]
	set leave_list [::lists::filter $actions {it {expr {[dict get $it action_type] == "leave"}}}]
	set action_list [::lists::filter $actions {it {expr {[dict get $it action_type] == "action"}}}]

	if {[llength $action_list] != 1} {
	    return -code error "invalid route action"
	}

	set action [lindex $action_list 0]
	set handler [dict get $action handler]
	set handler_type [dict get $action code_type]
	set enter_list [::lists::map $enter_list {it {
	    dicts list $it code_type handler
	}}]
	set leave_list [::lists::map $leave_list {it {
	    dicts list $it code_type handler
	}}]
	
	
	
	if {$method == "any"} {
	    set method ""
	}
	
	set route [dict create \
		       methods $method \
		       path $path \
		       handler $handler \
		       enter $enter_list \
		       leave $leave_list \
		       handler_type $handler_type]
	
	set results [prepare_route $route]
	set routes [list {*}$routes {*}$results]
    }

    #@param path ns path
    #@param order enter or leave
    #@action {method {code_type lambda,proc}}
    proc register_ns_middleware {path order action} {
	variable NsMiddlewareEnterList
	variable NsMiddlewareLeaveList

	switch $order {
	    enter {
		set ns_list [dicts get $NsMiddlewareEnterList $path {}]
		lappend ns_list $action
		dict set NsMiddlewareEnterList $path $ns_list
	    }
	    leave {
		set ns_list [dicts get $NsMiddlewareLeaveList $path {}]
		lappend ns_list $action
		dict set NsMiddlewareLeaveList $path $ns_list
	    }
	    default {
		return -code error "unkwnon middleware order $order"
	    }
	}	
    }

    #@param path
    #@action {code_type lambda,proc code {}}
    proc register_ns_recover_interceptor {path action} {
	variable NsRecoverInterceptorList
	set l [dicts get $NsRecoverInterceptorList $path {}]
	lappend l $action
	dict set NsRecoverInterceptorList $path $l
    }

    #@status http status code
    #@action {code_type lambda,proc code {}}
    proc register_ns_status_code_interceptor {path status action} {
	variable NsStatusCodeInterceptorList
	set l [dicts get $NsStatusCodeInterceptorList $path {}]
	lappend l [list $status $action]
	dict set NsStatusCodeInterceptorList $path $l
    }
    
    proc get_uri_query {uri} {
	set parts [split $uri ?]
	set queries [lindex $parts 1]
	set requestQuery [dict create]


	foreach {_ k v} [regexp -all -inline {[\?|&](.+?)=(.+?)&?} $uri] {
	    dict set requestQuery $k $v
	}

	puts "::> queries = $requestQuery"
	
	#foreach var [split $queries "&"] {
	#    if { [string trim $var] == "" } {
	#	continue
	#    }
	#    regexp {(\w+)=(\w+)} $var -> k v
	#set param [split $var "="]
	#set k [lindex $param 0] 
	#set v [lindex $param 1]
	#    dict set requestQuery $k $v 
	#}  
	return $requestQuery
    }

    # Extract route regexp and path variables
    # 
    # @param route_path
    # @return {<route regexp> <listkeyval variables>}
    proc extract_route_and_variables {route_path} {

	set variables {}

	set parts [split $route_path /]
	set n [llength $parts]
	set route ""
	
	for {set i 0} {$i < $n} {incr i} {

	    set part [lindex $parts $i]

	    if {$part == ""} {
		continue
	    }

	    # if path starts with : is path var
	    if {[string match :* $part]} {

		# find path var and regex
		#regexp -nocase {:([a-zA-Z_]*\(?/?)(\(.+\))?} $part -> param re
		# find by ^:(<var name>)(<pattern>)?
		regexp -nocase {:([a-zA-Z_\-]+)(\(.+\))?} $part -> param re
		#puts "::> param=$param, re=$re"

		# empty regex
		if {$re == ""} {
		    # all except /
		    set re {[^/]+}
		} else {
		    # remove ()
		    set re [string map {( "" ) ""} $re]
		    #set re [regsub {\(} $re ""]
		    #set re [regsub {\)} $re ""]								
		}

		set route "$route/($re)"

		lappend variables $param $re
	    } else {
		# no path var
		set route "$route/$part"
	    }
	}

	if {$route == ""} {
	    set route ^/$  
	} elseif {[string match {*/\*} $route]} {
	    set route "^${route}"
	} else {
	    set route "^${route}/?$"
	}


	#puts "::> $cfg_route $route $variables"
	
	return [list $route $variables]
    }

    proc prepare_route {cfg_route {last_path ""}} {

	variable log

	set routes {}

	set path [dict get $cfg_route path]
	set route [Route new]
	
	$route props \
	    routes [dicts get $cfg_route routes {}] \
	    roles [dicts get $cfg_route roles {}] \
	    methods [dicts get $cfg_route methods {}] \
	    handler [dicts get $cfg_route handler {}] \
	    handler_type [dicts get $cfg_route handler_type {}] \
	    enter [dicts get $cfg_route enter {}] \
	    leave [dicts get $cfg_route leave {}] \
	    websocket [dicts get $cfg_route websocket false] \
	    controller [dicts get $cfg_route controller {}] \
	    action [dicts get $cfg_route action {}] \
	    path $path


	set route_path $last_path$path

	#${log}::debug "route = $route_path"
	
	if {[$route has_subroutes]} {

	    if {[$route present handler]} {
		$route prop path $route_path
		lappend routes $route
	    }

	    set enter [$route prop enter]
	    set leave [$route prop leave]
	    set roles [$route prop roles]

	    foreach subroute_cfg [$route prop routes] {
		#set path [$subroute prop path]

		# merge with base route
		set enter_all [list {*}$enter {*}[dicts get $subroute_cfg enter {}]]
		set leave_all [list {*}$leave {*}[dicts get $subroute_cfg leave {}]]
		set roles_all [list {*}$roles {*}[dicts get $subroute_cfg roles {}]] 

		set subroute [Route new]
		$subroute props \
		    routes [dicts get $subroute_cfg routes {}] \
		    roles $roles_all \
		    methods [dicts get $subroute_cfg methods {}] \
		    handler [dicts get $subroute_cfg handler {}] \
		    handler_type [dicts get $subroute_cfg handler_type {}] \
		    enter $enter_all \
		    leave $leave_all \
		    websocket [dicts get $subroute_cfg websocket false] \
		    path [dict get $subroute_cfg path]


		set rds [prepare_route [$subroute to_dict] $route_path]

		foreach r $rds {
		    lappend routes $r
		}			
	    } 

	} else {
	    
	    set result [extract_route_and_variables $route_path]
	    lassign $result rePath variables
	    #set rePath [lindex $result 0]
	    #set variables [lindex $result 1]

	    # remove end / if need, and add regex to do / optional
	    if {[string match -nocase */ $route_path]} {
		#set rePath "[string range $rePath 0 end-1](/?)$"
		#set route_path [string range $route_path 0 end-1]
	    } 

	    $route prop path $route_path
	    $route prop repath $rePath
	    $route prop variables $variables
	    lappend routes $route
	}

	return $routes
    }
    
    proc build_config_routes {items} {

	variable routes

	#set items [::trails::configs::get web routes]

	set n [llength $items]	
	set all_routes {}

	foreach route $items {
	    set path [dict get $route path]
	    set results [prepare_route $route "" true]
	    foreach r $results {			
		lappend all_routes $r
	    }
	}	

	set routes [list {*}$routes {*}$all_routes]
    }

    proc build_scaffold_routes {scaffold_routes} {
	variable routes

	set all_routes {}

	foreach scaffold_route $scaffold_routes {
	    set scaffold_path [dict get $scaffold_route path]
	    set skip false
	    
	    foreach route $routes {
		# already configured
		if {[$route prop path] == $scaffold_path} {
		    #puts "::> skip route $scaffold_path"
		    set skip true
		    break
		}
	    }

	    if {!$skip} {
		#puts "::> prepare route $scaffold_path"
		set results [prepare_route $scaffold_route "" true]
		#puts "::> routes for $scaffold_path: [llength $results]"
		foreach r $results {			
		    lappend all_routes $r
		}			
	    }
	    
	}

	set routes [list {*}$routes {*}$all_routes]
    }

    proc get_routes {} {
	variable routes
	return $routes
    }

    proc set_routes {r} {
	variable routes
	set routes $r
    }

    # add ns middlewares on route
    # @param route Route
    proc configure_route_middlewares {method route} {
	variable NsMiddlewareLeaveList
	variable NsMiddlewareEnterList

	set results_enter {}
	set results_leave {}
	set rpath [$route prop path]
	# {method {code_type lambda,proc}}
	dict for {md_path var} $NsMiddlewareEnterList {
	    foreach it $var {
		lassign $it md_method code
		if {$md_method == "any" || [string match -nocase $md_method $method]} {
		    if {[regexp $md_path $rpath]} {
			lappend results_enter $code
		    }
		}
	    }
	}
	dict for {md_path var} $NsMiddlewareLeaveList {
	    foreach it $var {
		lassign $it md_method code
		if {$md_method == "any" || [string match -nocase $md_method $method]} {
		    if {[regexp $md_path $rpath]} {
			lappend results_leave $code
		    }
		}
	    }
	}
	
	$route propmerge enter $results_enter
	$route propmerge leave $results_leave
    }

    proc configure_route_recovers {route} {
	set rpath [$route prop path]
	set results [find_recovers $rpath]
	$route propmerge recovers $results
    }

    proc configure_route_interceptors {route} {
	set rpath [$route prop path]
	set results [find_interceptors $rpath "*"]
	$route propmerge interceptors $results
    }

    proc find_interceptors {rpath status_code} {
	variable NsStatusCodeInterceptorList
	set results {}
	dict for {path codes} $NsStatusCodeInterceptorList {
	    if {[regexp $path $rpath]} {
		foreach it $codes {
		    lassign $it status code
		    if {$status == $status_code || $status_code == "*"} {
			set items {}
			if {[dict exists $results $status]} {
			    set items [dict get $results $status]
			}
			lappend items $code
			dict set results $status $items
		    }
		}
	    }
	}
	return $results
    }

    proc find_recovers {rpath} {
	variable NsRecoverInterceptorList
	set results {}
	dict for {path code} $NsRecoverInterceptorList {
	    if {[regexp $path $rpath]} {
		lappend results $code
	    }
	}
	return $results
    }
    
    proc route_match {method path} {

	variable routes
	variable log

	set variables {}

	#puts "match $path $method, [llength $routes]"

	set routes_match {}
	
	foreach route $routes {
	    

	    set repath [$route prop repath]
	    set results [regexp -nocase -all -inline $repath $path]
	    if {[llength $results] == 0} {
		#puts "not match $path == $repath"
		continue
	    }			
	    
	    if {![$route has_method $method]} {
		continue
	    }

	    lappend routes_match $route
	}

	#puts "::> [lmap it $routes_match {$it prop path}]"

	set route_found {}

	if {[llength $routes_match] == 1} {
	    set route_found [lindex $routes_match 0]
	} elseif {[llength $routes_match] > 1} {

	    # search exact route
	    foreach route $routes_match {
		if {[$route prop path] == $path} {
		    set route_found $route
		    break
		}
	    }

	    # or else get first route
	    if {![info object isa object $route_found] || ![info object class $route_found Route]} {
		set route_found [lindex $routes_match 0]
	    }
	}	

	if {[info object isa object $route_found] && [info object class $route_found Route]} {
	    set variables [$route_found prop variables]
	    set n [llength $variables]
	    set vars {}

	    set i 0
	    foreach {var _} $variables {
		set val [lindex $results [incr i]]
		lappend vars $var $val			
	    }
	    
	    set ret [$route_found clone]
	    $ret prop params $vars

	    configure_route_middlewares $method $ret
	    configure_route_recovers $ret
	    configure_route_interceptors $ret
	    
	    return $ret					
	}

	return {}
    }
    
    proc print_routes {} {
	variable routes
	puts "::> Routes"
	puts "::>"

	if {[llength $routes] == 0} {
	    puts "::> 0 routes"
	}
	
	foreach route $routes {
	    set method [string toupper [$route prop methods]]
	    if {$method == ""} {
		set method ANY
	    }
	    puts "::> $method [$route prop path] -> [$route prop repath] [$route prop handler]"
	}
	puts "::>"	
    }

    proc print_interceptors {} {
	variable NsStatusCodeInterceptorList
	variable NsRecoverInterceptorList

	puts "::> Interceptors"
	puts "::>"

	if {[llength $NsStatusCodeInterceptorList] == 0 && [llength $NsRecoverInterceptorList] == 0} {
	    puts "::> 0 interceptors"
	}
	
	dict for {path values} $NsStatusCodeInterceptorList {
	    foreach keyval $values {
		foreach {status code} $keyval {}
		puts "::> $status $path -> $code"
	    }
	}
	
        dict for {path values} $NsRecoverInterceptorList {
	    foreach code $values {
		puts "::> recover $path -> $code"
	    }
	}

	puts "::> "
    }

    proc print_middlewares {} {
	variable NsMiddlewareLeaveList
	variable NsMiddlewareEnterList

	puts "::> Middlewares"
	puts "::>"

	if {[llength $NsMiddlewareLeaveList] == 0 && [llength $NsMiddlewareEnterList] == 0} {
	    puts "::> 0 middlewares"
	}
	
	dict for {path values} $NsMiddlewareEnterList {
	    foreach it $values {
		foreach {method code} $it {}
		puts "::> $method $path enter $code"
	    }
	}

    	dict for {path values} $NsMiddlewareLeaveList {
	    foreach it $values {
		foreach {method code} $it {}
		puts "::> $method $path leave $code"
	    }
	}
    }
}
