
package require logger
package require coroutine
package require tools

namespace import ::tools::dicts::*
namespace import ::tfast::router::*

namespace eval ::tfast::http {

    namespace export \
	http_init \
	http_accept \
	add_controller \
	dispatch \
	register_public_path \
	register_public_extension \
	register_filter_proc \
	register_filter_instance \
	print_debug
	
	
    
    variable Controllers
    variable FiltersObjs
    variable FiltersProcs
    variable PublicPaths
    variable PublicExtsEnableds
    variable log

    set log [logger::init tfast::http::http_server]

    set Controllers {}
    set FiltersObjs {}
    set FiltersProcs {}
    set PublicPaths {}
    set PublicExtsEnableds {}

    # register public path
    proc register_public_path {path} {
	variable PublicPaths
        lappend PublicPaths $path
    }

    # register filter by proc
    proc register_filter_proc {filter} {
	variable FiltersProcs
	lappend FiltersProcs $filter
    }

    # register filter by object
    proc register_filter_instance {filter} {
	variable FiltersObjs
	lappend FiltersObjs $filter
}

    # configure extensions enabled on public path
    proc register_public_extension {exts} {
	variable PublicExtsEnableds
	lappend PublicExtsEnableds $exts
    }
    
    # add controller instance on cache
    proc add_controller {ctrl} {
	variable Controllers
	dict set Controllers [info object class $ctrl] $ctrl
    }

    proc fix_response_content_type {response} {
	set hctype [$response header Content-Type]
	set ctype [$response content-type]

	if {$hctype == ""} {
	    $response header Content-Type $ctype
	}
    }
    
    proc handle_request {req} {

	variable log
	
	set request [Request new \
			 -path [dict get $req path] \
			 -method [dict get $req method] \
			 -body [dict get $req body] \
			 -headers [dict get $req headers] \
			 -queries [dict get $req queries]]

	try {
	    set response [filter_and_dispatch $request]

	    fix_response_content_type $response
	    
	    dict create \
		status [$response status] \
		body [$response body] \
		headers [$response headers]
	    
	} on error err {
	    ${log}::error "$err: $::errorInfo"

	    dict create \
		status 500 \
		body "$err: $::errorInfo" \
		headers {Content-Type text/plain}
	}
    }
    
    # handle http request
    proc handle {socket addr port} {
	variable log
	set start_time [clock milliseconds]

	if {[eof $socket]} {
	    ${log}::debug {channel is closed}
	    http_connecton_close $socket
	    return
	}

	try {
	    
	    set request [parse_request $socket]
	    set response [filter_and_dispatch $request]

	    fix_response_content_type $response
	    
	    if {[$response bool websocket]} {
		${log}::debug "do websocket upgrade ${wsServer}"
		set wsServer [app::get_ws_socket]
		set headers [websocket_app::check_headers $headers]        
		websocket_app::upgrade $wsServer $socket $headers      
	    } else {
		send_response $socket $response        
	    }

	} on error err {

	    ${log}::error "$err: $::errorInfo"

	    if {$err != "no data received -> close socket"} {
		server_error $socket -body $err
	    }

	} finally {

	    set has_response false
	    set is_websocket false

	    if {[info exists request] && [is_request $request]} {
		set diff [expr {[clock milliseconds] - $start_time}]
		${log}::debug "[$request method] [$request path] ${diff}ms"
		$request destroy
	    }      

	    if {[info exists response] && [is_response $response]} {
		set has_response true
	    }

	    if {$has_response} {
		set is_websocket [$response bool websocket]
		$response destroy
	    }      

	    if {!$is_websocket} {
		http_connecton_close $socket 
	    }
	}
    }

    proc http_connecton_close {socket} {
	catch {close $socket}
    }

    proc is_response {result} {
	expr {[info object isa object $result] && [info object class $result Response]}
    }

    proc is_request {result} {
	expr {[info object isa object $result] && [info object class $result Request]}
    }

    proc apply_object_filter_enter {request} {
	variable FiltersObjs
	foreach filter $FiltersObjs {
	    set methods [info object methods $filter -all]
	    if {[lsearch -exact $methods enter] > -1} {
		set result [$filter enter $request]
		if {[is_response $result]} {
		    return $result
		} elseif {[is_request $result]} {
		    set request $result
		} else {
		    return -code error {wrong filter result}
		}          
	    }
	}
	return $request
    }

    proc apply_proc_filter_enter {request} {
	variable FiltersProcs
	set filters_enter [dicts get $FiltersProcs enter {}]
	foreach enter $filters_enter {
	    set result [$enter $request]
	    if {[is_response $result]} {
		return $result
	    } elseif {[is_request $result]} {
		set request $result
	    } else {
		return -code error {wrong filter result}
	    }
	}  
	return $request
    }

    proc apply_object_filter_leave {request response} {
	variable FiltersObjs
	foreach filter $FiltersObjs {
	    set methods [info object methods $filter -all]
	    if {[lsearch -exact $methods leave] > -1} {
		set response [$filter leave $request $response]
		if {![is_response $response]} {
		    return -code error {wrong filter result}
		}      
	    }
	}
	return $response
    }

    proc apply_proc_filter_leave {request response} {
	variable FiltersProcs
	set filters_leave [dicts get $FiltersProcs leave {}]
	foreach leave $filters_leave {  
	    set response [$leave $request $response]
	    if {![is_response $response]} {
		return -code error {wrong filter result}
	    }
	}
	return $response
    }

    proc apply_object_filter_recover {request} {
	variable FiltersObjs
	set response {}
	foreach filter $FiltersObjs {
	    set methods [info object methods $filter -all]
	    if {[lsearch -exact $methods recover] > -1} {
		set response [$filter recover $request $err]
		if {![is_response $result]} {
		    return -code error {wrong recover result}
		}                  
	    }
	}
	return $response
    }
    

    proc apply_proc_filter_recover {request} {
	variable FiltersProcs
	set response {}
	set filters_recover [dicts get $FiltersProcs recover {}]
	foreach recover $filters_recover {
	    set response [$recover $request $err]
	    if {![is_response $response]} {
		return -code error {wrong recover result}
	    }
	}
	return $response
    }

    proc apply_route_recovers {request} {
	set recovers [find_recovers [$request prop path]]
	set response = {}
	foreach recover $recovers {
	    lassign $recover code_type code
	    if {$code_type == "proc"} {
		set response [$code $request]
	    } elseif {$code_type == "lambda"} {
		set response [apply $code $request]
	    } else {
		return -code error "unknown recover code type $code_type"
	    }
	    if {![is_response $response]} {
		return -code error {wrong recover result}
	    }
	}
	return $response
    }

    proc apply_route_interceptors {request response} {
	set interceptors [find_interceptors [$request prop path] [$response prop status]]	
	foreach interceptor $interceptors {
	    # TODO apply interceptos by status code
	    lassign $interceptor code_type code
	    if {$code_type == "proc"} {
		set response [$code $request $reponse]
	    } elseif {$code_type == "lambda"} {
		set response [apply $code $request $response]
	    } else {
		return -code error "unknown interceptor code type $code_type"
	    }
	    if {![is_response $response]} {
		return -code error {wrong interceptor result}
	    }
	}
	return $response
    }

    proc filter_and_dispatch {request} {

	variable log
	
	set error_state false
	
	try {
	    set result [apply_object_filter_enter $request]

	    if {[is_request $result]} {
		set result [apply_proc_filter_enter $request]
	    }
	
	    if {[is_response $result]} {
		return $result
	    } elseif {[is_request $result]} {
		set request $result
	    } else {
		return -code error {wrong filter result}
	    }
	
	    set response [dispatch $request]
	    
	} on error err {
	    set error_state true
	    ${log}::error $err
	    puts $::errorInfo

	    set result [apply_route_recovers $request]

	    if {![is_response $result]} {
		set result [apply_object_filter_recover $request]
	    }

	    if {![is_response $result]} {
		set result [apply_proc_filter_recover $request]
	    }

	    if {[is_response $result]} {
		set response $result
	    }   
		
	    if {![info exists response]} {
		set response [Response new -status 500 -body "Server error: $err"]
	    }
	}

	set response [apply_object_filter_leave $request $response]

	if {![is_response $response]} {
	    return -code error {wrong object leave response}
	}

	set response [apply_proc_filter_leave $request $response]
	
	if {![is_response $response]} {
	    return -code error {wrong proc leave response}
	}

	set response [apply_route_interceptors $request $response]
	
	if {![is_response $response]} {
	    return -code error {wrong interceptor response}
	}

	return $response
    }

    proc dispatch {request} {

	variable log
	variable Controllers
	variable PublicPaths
	variable PublicExtsEnableds
	
	set path [$request prop path]
	set query [$request prop query]
	set method [$request prop method]
	set contentType [$request prop content-type]
	set headers [$request prop headers]
	set is_websocket false

	${log}::debug "$method $path"

	if {[string match "/public/*" $path]} {

	    foreach path $PublicPaths {
		set map {} 
		lappend map "/public" $path
		set f [string map $map $path]
		set ext [file extension $f]

		if {[llength $PublicExtsEnableds] > 0} {
		    if {![lsearch $PublicExtsEnableds $ext] > -1} {
			${log}::debug "file extension $ext not enabled"
			return [Response new -status 404 -content-type $contentType]
		    }
		}
		
		if {[file exists $f]} {
		    return [Response new -file $f]
		}
	    }

	    return [Response new -status 404 -content-type $contentType]

	} else {

	    try {
		# router match
		set route [route_match $method $path]

		if { $route == "" } {
		    ${log}::debug "404 $method $path"
		    return [Response new -status 404 -content-type $contentType]
		}

		set is_websocket [$route prop websocket]

		if { ![$route can_handle] && !$is_websocket } {
		    return [Response new -status 500 -body {route can't be handled} -content-type $contentType]
		}

		$request props \
		    params [$route prop params] \
		    roles [$route prop roles] \
		    route $route

		set enter_handlers [$route prop enter]
		set leave_handlers [$route prop leave]

		foreach handler $enter_handlers {

		    lassign $handler code_type code

		    if {$code_type == "proc"} {o
			set next [$code $request]
		    } elseif {$code_type == "lambda"} {
			set next [apply $code $request]
		    } else {
			return -code error "unknown enter middleware code type $code_type"
		    }

		    if {[info object class $next Request]} {
			set request $next
		    } elseif {[info object class $next Response]} {
			return $next
		    } else {
			return [Response new -status 500 -body {wrong filter return type} -content-type $contentType]
		    }
		}

		if {$is_websocket} {
		    return [Response new -websocket true]
		}

		if {[$route has_handler]} {

		    set handler_type [$route prop handler_type]
		    set handler [$route prop handler]

		    if {$handler_type == "proc"} {
			set response [$handler $request]
		    } elseif {$handler_type == "lambda"} {
			set response [apply $handler $request]
		    } else {
			return -code error "unknown handler type $handler_type"
		    }
		    
		    
		} elseif {[$route has_controller]} {
		    
		    set ctrl [$route prop controller]
		    set action [$route prop action]

		    if {[dict exists $Controllers $ctrl]} {
			set crtl_instance [dict get $Controllers $ctrl]
		    } else {
			set crtl_instance [$ctrl new]
			$crtl_instance controller_configure
			add_controller $crtl_instance
			#dict set Controllers $ctrl $crtl_instance
		    }

		    set response [$crtl_instance dispatch_action $action $request]

		} else {
		    return [Response new -status 500 -body {route handler not found} -content-type $contentType]
		}

		if {![info object isa object $response] || ![info object class $response Response]} {
		    set response [parse_response $request $response]
		} 

		foreach handler $leave_handlers {
		    lassign $handler code_type code

		    if {$code_type == "proc"} {
			set response [$code $request $response]  
		    } elseif {$code_type == "lambda"} {
			set response [apply $code $request $response]
		    } else {
			return -code error "unknown leave middleware code type $code_type"
		    }
		    
		    if {![info object class $response Response]} {
			return [Response new -status 500 -body {wrong filter return type} -content-type $contentType]
		    }        
		}

		return $response

	    } finally {
		if {[info exists route] && [info object isa object $route]} {
		    $route destroy
		}      
	    }
	}        
    }
    # {200 {body content} text/plain {headers}}
    # {text {bdody} -headers {} -status {}}
    # {json {bdody} -headers {} -status {}}
    # {html {bdody} -headers {} -status {}}
    # {template name context}
    proc parse_response {request response} {
	variable log
	
	#puts "::> response $response"

	set n [llength $response]

	if {$n == 0 || $n > 4} {      
	    ${log}::debug "response list expect count > 0 and < 4, but receive count $n"
	    return -code error {invalid response}            
	}

	set first [lindex $response 0]
	set resp [Response new -content-type [$request prop content-type] -status 200]

	switch -regexp -- $first {
	    text|json|html {
		if {$n == 1} {
		    ${log}::debug "response list expect count > 1, but receive count $n"
		    return -code error {invalid response}
		}

		set ctype text/plain

		switch $first {
		    json { set ctype application/json }
		    html { set ctype text/html }
		}

		$resp prop content-type $ctype
		$resp prop body [lindex $response 1]

		set idx [lsearch -exact $response -headers]
		if {$idx > -1} {
		    $resp prop headers [lindex $response [incr idx]]                
		}

		set idx [lsearch -exact $response -status]
		if {$idx > -1} {
		    $resp prop status [lindex $response [incr idx]]                
		}

	    }
	    template {
		# TODO  implements template
	    }
	    {[0-9]+} {
		$resp prop status $first
		if {$n > 1} {
		    $resp prop body [lindex $response 1]
		}
		if {$n > 2} {
		    $resp prop content-type [lindex $response 2]
		}
		if {$n > 3} {
		    $resp prop headers [lindex $response 3]
		}
	    } 
	    default {
		${log}::debug {wrong response list}
		return -code error {invalid response}
	    }
	}
	return $resp    
    }

    proc print_debug {} {
	variable PublicPaths
	variable PublicExtsEnableds
	variable FiltersObjs
	variable FiltersProcs

	puts "::> public -> $PublicPaths, exts: $PublicExtsEnableds"
	puts "::> filters proc -> $FiltersProcs"
	puts "::> filters objects -> $FiltersObjs"
	puts "::>"
    }
}

