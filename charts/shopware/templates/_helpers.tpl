{{- define "generatePassword" -}}
{{- randAlphaNum 18 | nospace -}}
{{- end -}}

{{- define "generatePasswordEncoded" -}}
{{- randAlphaNum 18 | nospace | b64enc -}}
{{- end -}}

# TODO: This should be set hard coded and if not set it can maybe be generated.
# It's probably not required to set the applicationName projectName and org by this helm chart.
{{ define "generateHost" -}}
{{- if hasKey .Values.store "host" }}
{{- .Values.store.host }}
{{- else }}
{{- printf "localhost.traefik.me" }}
{{- end }}
{{- end -}}

{{ define "generateS3URLConsole" -}}
{{- if hasKey .Values.store "host" }}
{{- printf "s3-console.%s" .Values.store.host }}
{{- else }}
{{- printf "s3-console.localhost.traefik.me" }}
{{- end }}
{{- end -}}

{{ define "generateS3URLApi" -}}
{{- if hasKey .Values.store "host" }}
{{- printf "s3-api.%s" .Values.store.host }}
{{- else }}
{{- printf "s3-api.localhost.traefik.me" }}
{{- end }}
{{- end -}}

{{ define "getDBService" -}}
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
privateBucketName: {{ .Values.store.s3Storage.privateBucketName | default "shopware-private" }}
publicBucketName: {{ .Values.store.s3Storage.publicBucketName | default "shopware-public" }}
accessKeyRef:
  {{ toYaml .Values.store.s3Storage.accessKeyRef  | indent 6 }}
secretAccessKeyRef:
  {{ toYaml .Values.store.s3Storage.secretAccessKeyRef | indent 6 }}
{{- end}}
{{- end -}}

{{ define "getRedisAppMasterService" -}}
{{ printf "%s-redisapp-master" .Release.Name }}
{{- end -}}

{{ define "getRedisSessionMasterService" -}}
{{ printf "%s-redissession-master" .Release.Name }}
{{- end -}}

{{ define "getRedisReplicasService" -}}
{{ printf "%s-redis-replicas" .Release.Name }}
{{- end -}}

{{ define "getOpenSearchClusterName" -}}
{{ printf "%s-opensearch-cluster" .Release.Name }}
{{- end -}}

{{ define "getCaddyConfigName" -}}
{{ printf "%s-caddy-config" .Release.Name }}
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
