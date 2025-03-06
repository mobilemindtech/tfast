package require uuid
package require coroutine
package require logger
package require EasyBeast
package require tools

namespace import ::tools::dicts

namespace eval ::tfast::http::backend::easybeast {

    variable log

    set log [logger::init ::tfast::http::backend::easybeast]
    
    proc handle {req} {
	variable log
	set path [dict get $req path]
	set requestQuery [::tfast::router::get_uri_query $path]
	        
	# remove query from URI
	set requestURI [lindex [split $path ?] 0]

	dict set req path $requestURI
	dict set req queries $requestQuery

	try {
	    set resp [::tfast::http::handle_request $req]
	    return $resp
	} on error err {
	    ${log}::error "$err: $::errorInfo"
	}

	set heades [dict get $req headers]
	set ctype [dicts get $headers Content-Type text/plain]
	dict create \
	    status 500 \
	    body "server error" \
	    headers [list Content-Type $ctype]
    }

    proc serve {host port workers} {
	::easybeast::serve $host $port [namespace current]::handle
    }
}
