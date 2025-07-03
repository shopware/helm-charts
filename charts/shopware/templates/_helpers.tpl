{{- define "generatePassword" -}}
{{- randAlphaNum 18 | nospace -}}
{{- end -}}

{{- define "generatePasswordEncoded" -}}
{{- randAlphaNum 18 | nospace | b64enc -}}
{{- end -}}

{{ define "generateS3URLConsole" -}}
{{- if hasKey .Values.store "host" }}
{{- printf "s3-console-%s" .Values.store.host }}
{{- else }}
{{- printf "s3-console.localhost.traefik.me" }}
{{- end }}
{{- end -}}

{{ define "generateS3URLApi" -}}
{{- if hasKey .Values.store "host" }}
{{- printf "s3-api-%s" .Values.store.host }}
{{- else }}
{{- printf "s3-api.localhost.traefik.me" }}
{{- end }}
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
{{- if .Values.minio.enabled }}
{{- if .Values.minio.useTLS }}
endpointURL: "https://minio.{{ .Release.Namespace }}.svc.cluster.local"
{{- else }}
endpointURL: "http://minio.{{ .Release.Namespace }}.svc.cluster.local"
{{- end }}
privateBucketName: "shopware-private"
publicBucketName: "shopware-public"
accessKeyRef:
  name:  {{ template "getTenantUserSecretName" . }}
  key: "CONSOLE_ACCESS_KEY"
secretAccessKeyRef:
  name: {{ template "getTenantUserSecretName" . }}
  key: "CONSOLE_SECRET_KEY"

{{- if hasKey .Values.store "s3Storage" }}
{{- fail "If you use MinIO the s3Storage variables will get overwritten! Please remove them" }}
{{- end }}

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
{{- end}}
{{- end -}}

{{ define "getSessionCacheMasterService" -}}
{{- if .Values.valkeysession.enabled }}
{{- printf "%s-valkeysession-master" .Release.Name }}
{{- else }}
{{- printf "%s-redissession-master" .Release.Name }}
{{- end }}
{{- end -}}

{{ define "getAppCacheMasterService" -}}
{{- if .Values.valkeyapp.enabled }}
{{- printf "%s-valkeyapp-master" .Release.Name }}
{{- else }}
{{- printf "%s-redisapp-master" .Release.Name }}
{{- end }}
{{- end -}}

{{ define "getWorkerMasterService" -}}
{{- if .Values.valkeyworker.enabled }}
{{- printf "%s-valkeyworker-master" .Release.Name }}
{{- else }}
{{- printf "%s-redisworker-master" .Release.Name }}
{{- end }}
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

{{ define "getBlackfireServiceName" -}}
{{ "blackfire" }}
{{- end -}}

{{ define "getTenantUserSecretName" -}}
{{ "store-s3-shopware" }}
{{- end -}}

{{ define "getTenantUserSecretAccessKeyName" -}}
{{ "CONSOLE_SECRET_KEY" }}
{{- end -}}

{{ define "getTenantUserAccessKeyName" -}}
{{ "CONSOLE_ACCESS_KEY" }}
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
