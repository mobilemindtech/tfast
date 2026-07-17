namespace eval ::tfast::http::middleware {
	# cors {origin * methods * headers * max-age 3600}
  proc cors {args} {
    set code {{req} {
        set origin [$req header Origin]
        set resp [Response new -status 200]
        set items [list __args__]
        set origin [lists findnext $items origin]
        set methods [lists findnext $items methods]
        set headers [lists findnext $items headers]
        set maxAge [lists findnext $items max-age]

        if {$origin != ""} {
          $resp header Access-Control-Allow-Origin $origin
        }
        if {$methods != ""} {
          $resp header Access-Control-Allow-Methods $methods
        }
        if {$headers != ""} {
          $resp header Access-Control-Allow-Headers $headers
        }
        if {$methods != ""} {
          $resp header Access-Control-Max-Age $methods
        }

        $resp header Content-Type text/plain

        return $resp
    }}
    regsub "__args__" $code "$args" new_code
    return $new_code
  }
}