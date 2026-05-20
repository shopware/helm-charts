{{- define "composable-frontends.fullname" -}}
{{- printf "%s-composable-frontends" .Release.Name -}}
{{- end -}}

{{- define "composable-frontends.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- include "composable-frontends.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "composable-frontends.labels" -}}
app.kubernetes.io/name: composable-frontends
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/part-of: composable-frontends
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}

{{- define "composable-frontends.selectorLabels" -}}
app.kubernetes.io/name: composable-frontends
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
