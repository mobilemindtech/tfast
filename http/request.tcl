package require TclOO
package require tools

namespace import ::tools::props::*
namespace import ::tools::dicts::*

namespace eval ::tfast::http {

    namespace export Request	

    oo::class create Request {

	superclass Props

	constructor {args} {
	    next method \
		path \
		pathlist \
		pathtail \
		raw-body \
		body \
		query \
		params \
		headers \
		content-type \
		roles \
		route

	    foreach {k v} $args {
		switch -regexp -- $k {
		    -method|method {
			my prop method $v
		    }
		    -path|path {
			my prop path $v
		    }
		    -body|body {
			my prop body $v
		    }	
		    -raw-body|raw-body {
			my prop raw-body $v
		    }	
		    -query|query {
			my prop query $v
		    }
		    -params|params {
			my prop params $v
		    }					
		    -headers|headers {
			my prop headers $v
		    }
		    -content-type|content-type {
			my prop content-type $v
		    }					
		}
	    }
	}

	method header {name args} {
	    set headers [my prop headers]
	    if {[llength $args] > 0} {
		dict set headers $name [lindex $args 0]
		my prop headers $headers
	    } else {
		dicts get $headers $name {}
	    }
	}

	# Test if is given method
	# @param verb 
	method is {verb} {
	    expr {[my prop method] == $verb}
	}

	method body {args} {
	    my prop body {*}$args
	}

	method headers {args} {
	    my prop headers {*}$args
	}

	method method {args} {
	    my prop method {*}$args
	}

	method path {} {
	    my prop path
	}
	
	method content-type {args} {
	    my prop content-type {*}$args
	}
    }
}
