# @scope: fetch
# Pass immediately if x-pass is present
if (req.http.x-pass) {
  return (pass);
}

if (beresp.http.Cache-Control ~ "private|no-cache|no-store") {
  set req.http.Fastly-Cachetype = "PRIVATE";
  return (pass);
}

# If the object is coming with no Expires, Surrogate-Control or Cache-Control headers we assume it's a misconfiguration
# and should not cache it. This is to prevent inadventently caching private data
if (!beresp.http.Expires && !beresp.http.Surrogate-Control ~ "max-age" && !beresp.http.Cache-Control ~ "(s-maxage|max-age)") {
  # Fastly sets default TTL if none of the headers above are present. If not set we want to make sure we don't cache it.
  # Use hit-for-miss instead of hit-for-pass, so a later cacheable response can replace the marker immediately.
  set beresp.ttl = 60s;
  set beresp.cacheable = false;
  return(deliver);
}