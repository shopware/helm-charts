{{- define "generatePassword" -}}
{{- randAlphaNum 18 | nospace -}}
{{- end -}}

{{- define "generatePasswordEncoded" -}}
{{- randAlphaNum 18 | nospace | b64enc -}}
{{- end -}}

{{ define "getPerconaDBHost" -}}
{{- if hasKey .Values.percona "proxy" }}
{{- if .Values.percona.proxy.enabled }}
{{- printf "%s-proxysql" .Release.Name }}
{{- else -}}
{{- printf "%s-pxc" .Release.Name }}
{{- end }}
{{- end }}
{{- end -}}

{{ define "getStoreS3" -}}
{{- if .Values.rustfs.enabled }}
endpointURL: "http://{{ .Release.Name }}-rustfs-svc.{{ .Release.Namespace }}.svc.cluster.local:9000"
privateBucketName: "shopware-private"
publicBucketName: "shopware-public"
accessKeyRef:
  name: {{ .Release.Name }}-rustfs-secret
  key: RUSTFS_ACCESS_KEY
secretAccessKeyRef:
  name: {{ .Release.Name }}-rustfs-secret
  key: RUSTFS_SECRET_KEY
{{- else }}
endpointURL: {{ .Values.store.s3Storage.endpointURL | default "https://s3.eu-central-1.amazonaws.com" }}
privateBucketName: {{ .Values.store.s3Storage.privateBucketName | default "shopware-private" }}
publicBucketName: {{ .Values.store.s3Storage.publicBucketName | default "shopware-public" }}
region: {{ .Values.store.s3Storage.region | default "eu-central-1" }}
{{- if .Values.store.s3Storage.accessKeyRef }}
accessKeyRef:
  {{ toYaml .Values.store.s3Storage.accessKeyRef  | nindent 2 }}
{{- end }}
{{- if .Values.store.s3Storage.secretAccessKeyRef }}
secretAccessKeyRef:
  {{ toYaml .Values.store.s3Storage.secretAccessKeyRef | nindent 2 }}
{{- end }}
{{- end }}
{{- end -}}

{{ define "getSessionCacheMasterService" -}}
{{- printf "%s-valkeysession-master" .Release.Name }}
{{- end -}}

{{ define "getAppCacheMasterService" -}}
{{- printf "%s-valkeyapp-master" .Release.Name }}
{{- end -}}

{{ define "getWorkerMasterService" -}}
{{- printf "%s-valkeyworker-master" .Release.Name }}
{{- end -}}

{{ define "getCaddyConfigName" -}}
{{ printf "%s-caddy-config" .Release.Name }}
{{- end -}}

{{ define "getFluentBitName" -}}
{{ printf "%s-fluent-bit" .Release.Name }}
{{- end -}}

{{ define "getMonologConfigName" -}}
{{ printf "%s-monolog-config" .Release.Name }}
{{- end -}}

{{ define "getPerconaSecrets" -}}
{{ "percona-secrets" }}
{{- end -}}

{{ define "getMariaDBHost" -}}
{{- .Release.Name }}
{{- end -}}

{{ define "getMariaDBSecretName" -}}
{{- printf "%s-root" .Release.Name }}
{{- end -}}

{{ define "getBlackfireServiceName" -}}
{{ "blackfire" }}
{{- end -}}

{{ define "blackfireCredentialsRef" -}}
{{- if hasKey .Values "blackfire" -}}
{{- if and (hasKey .Values.blackfire "serverIDRef") (hasKey .Values.blackfire "serverTokenRef") -}}
true
{{- end -}}
{{- end -}}
{{- end -}}

{{ define "getTidewaysServiceName" -}}
{{ "tideways" }}
{{- end -}}

{{ define "tidewaysCredentialsRef" -}}
{{- if hasKey .Values "tideways" -}}
{{- if hasKey .Values.tideways "apiKeyRef" -}}
true
{{- end -}}
{{- end -}}
{{- end -}}

# Defined by the operator itself
{{ define "getStoreDeploymentName" -}}
{{ printf "%s-store" .Release.Name }}
{{- end -}}

{{ define "caddyLogPath" -}}
{{- $fluentBitCaddyInputPath := printf "%s/%s"  (.Values.store.sidecarLogging.logFolderCaddy | default "/var/log") (.Values.store.sidecarLogging.logFileCaddy | default "caddy.log") -}}
{{ $fluentBitCaddyInputPath }}
{{- end -}}

{{ define "fluentBitConfigmap" -}}
{{- if hasKey .Values.store "sidecarLogging" }}
{{- $fluentBitShopwareInputPath := printf "Path %s/%s"  (.Values.store.sidecarLogging.logFolder | default "/var/log") (.Values.store.sidecarLogging.logFile | default "shopware.log") -}}
[SERVICE]
    Daemon Off
    Flush 1
    Log_Level info
    Parsers_File /fluent-bit/etc/parsers.conf
    Parsers_File /fluent-bit/etc/conf/custom_parsers.conf
    HTTP_Server On
    HTTP_Listen 0.0.0.0
    HTTP_Port 2020
    Health_Check On

[INPUT]
    Name tail
    {{ $fluentBitShopwareInputPath }}
    Refresh_Interval 5
    Parser shopware
    Tag shopware
    Mem_Buf_Limit 5MB
    Skip_Long_Lines On

[INPUT]
    Name tail
    Path {{ include "caddyLogPath" . }}
    Refresh_Interval 5
    Parser shopware
    Tag caddy
    Mem_Buf_Limit 5MB
    Skip_Long_Lines On

[FILTER]
    Name grep
    Match *
    Exclude $context['route'] api.info.health.check

[FILTER]
    Name grep
    Match caddy
    Exclude $request['uri'] api/_info/health-check

[OUTPUT]
    Name         loki
    Match        *
    Host         {{ .Values.store.sidecarLogging.lokiHost | default "loki-gateway.loki.svc.cluster.local" }}
    Port         80
    Tls          off
    Labels       job=fluentbit,service=shopware
    Match        shopware
    auto_kubernetes_labels on
    tenant_id    tenant-{{ .Release.Namespace }}

[OUTPUT]
    Name         loki
    Match        *
    Host         {{ .Values.store.sidecarLogging.lokiHost | default "loki-gateway.loki.svc.cluster.local" }}
    Port         80
    Tls          off
    Labels       job=fluentbit,service=caddy
    Match        caddy
    auto_kubernetes_labels on
    tenant_id    tenant-{{ .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
php-fpm kills workers after this many seconds. It stays 5s above the Caddy read timeout
so that Caddy answers with a timeout (504) first and php-fpm then frees the worker.
A lower value would kill requests Caddy still waits for and turn them into 502s.
Supports Caddy durations made of hours, minutes and seconds ("60s", "1m", "1m30s").
Renders nothing when the read timeout is disabled.
*/}}
{{ define "getRequestTerminateTimeout" -}}
{{- $duration := toString .Values.store.caddy.readTimeout -}}
{{- $seconds := 0 -}}
{{- range $unit, $factor := dict "h" 3600 "m" 60 "s" 1 -}}
{{- with regexFind (printf "[0-9]+%s" $unit) $duration -}}
{{- $seconds = add $seconds (mul (trimSuffix $unit . | atoi) $factor) -}}
{{- end -}}
{{- end -}}
{{- if gt $seconds 0 -}}
{{- add $seconds 5 -}}
{{- end -}}
{{- end }}

{{/*
Renders an admin or storefront deployment container spec. The requestTerminateTimeout is
derived from the Caddy read timeout unless the user set it, so both can be overridden separately.
Expects a dict with the root context ("root") and the user supplied spec ("spec").
*/}}
{{ define "renderFpmDeploymentContainer" -}}
{{- $spec := deepCopy (default dict .spec) -}}
{{- if not (hasKey $spec "requestTerminateTimeout") -}}
{{- $seconds := include "getRequestTerminateTimeout" .root -}}
{{- if $seconds -}}
{{- $_ := set $spec "requestTerminateTimeout" (printf "%ss" $seconds) -}}
{{- end -}}
{{- end -}}
{{- if $spec -}}
{{- toYaml $spec -}}
{{- end -}}
{{- end }}
