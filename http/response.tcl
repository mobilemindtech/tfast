package require tools

namespace import ::tools::props::*
namespace import ::tools::dicts::*

namespace eval ::tfast::http {

    namespace export Response

    oo::class create Response {

	superclass Props

	constructor {args} {
	    
	    next body \
		headers \
		status \
		content-type \
		file \
		websocket \
		tpl-name \
		tpl-path \
		tpl-text \
		tpl-json \
		ctx

	    my prop status 200
	    my prop content-type text/plain
	    
	    foreach {k v} $args {
		switch -- $k {
		    -status -
		    status  {
			my prop status $v
		    }
		    -body -
		    body {
			my prop body $v
		    }
		    -content-type -
		    content-type {
			my prop content-type $v
		    }				
		    -headers -
		    headers {
			my prop headers $v
		    }
		    -json -
		    json {
			my props body $v content-type {application/json} 
		    }				
		    -text -
		    text {
			my props body $v content-type {text/plain} 
		    }				
		    -html -
		    html {
			my props body $v content-type {text/html} 
		    }	
		    -file -
		    file {
			my prop file $v
		    }
		    -ctx -
		    ctx {
			my prop ctx $v
		    }
		    -tpl-name -
		    tpl-name {
			my props tpl-name $v content-type {text/html}
		    }
		    -tpl-path -
		    tpl-path {
			my props tpl-path $v content-type {text/html}
		    }
		    -tpl-text -
		    tpl-text {
			my props tpl-text $v content-type {text/html}
		    }		
		    -tpl-json -
		    tpl-json {
			my props tpl-json $v content-type {application/json}
		    }								
		    -websocket -
		    websocket {
			my prop websocket $v
		    }			
		}
	    }
	}

	method body {args} {
	    my prop body {*}$args
	}

    	method status {args} {
	    my prop status {*}$args
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

	method headers {args} {
	    my prop headers {*}$args
	}
	
	method content-type {args} {
	    my prop contgent-type {*}$args
	}
    }
}



