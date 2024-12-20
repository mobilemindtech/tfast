
package require tools

namespace import ::tools::dicts::*
namespace import ::tools::props::*

namespace eval ::tfast::router {

    namespace export Route
    
    oo::class create Route {
	
	superclass Props

	constructor {} {
	    next \
		routes \
		roles \
		methods \
		handler \
		handler_type \
		enter \
		leave \
		recovers \
		interceptors \
		websocket \
		path \
		controller \
		action \
		repath \
		variables \
		params
	}

	method has_subroutes {} {
	    set l [llength [my prop routes]]
	    expr {$l > 0}
	}

	method has_method {method} {
	    set methods [my prop methods]
	    set methods [split $methods ,]

	    if {[llength $methods] == 0} {
		return true
	    }

	    foreach m $methods {
		if {[string toupper $method] == [string toupper $m]} {
		    return true
		}
	    }
	    return false
	}		

	method can_handle {} {
	    expr {[my present handler] || ([my present controller] && [my present action])}
	}

	method has_handler {} {
	    expr {[my present handler]}
	}

	method has_controller {} {
	    expr {[my present controller]}
	}

	method clone {} {
	    variable allowed_props
	    set route [Route new]
	    foreach name $allowed_props {
		$route prop $name [my prop $name]
	    }
	    return $route
	}
    }
}
