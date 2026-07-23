{{/*
Expand the name of the chart.
*/}}
{{- define "health-check-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "health-check-operator.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "health-check-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "health-check-operator.labels" -}}
helm.sh/chart: {{ include "health-check-operator.chart" . }}
{{ include "health-check-operator.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels.
*/}}
{{- define "health-check-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "health-check-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
control-plane: controller-manager
{{- end -}}

{{/*
Service account name.
*/}}
{{- define "health-check-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (printf "%s-controller-manager" (include "health-check-operator.fullname" .)) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Metrics service name. Keep this short enough for Kubernetes' 63-character DNS label limit.
*/}}
{{- define "health-check-operator.metricsServiceName" -}}
{{- printf "%s-metrics" (include "health-check-operator.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Container port derived from the health probe bind address, so the two cannot drift apart.
*/}}
{{- define "health-check-operator.healthPort" -}}
{{- splitList ":" .Values.healthProbe.bindAddress | last -}}
{{- end -}}

{{/*
Container port derived from the metrics bind address, so the two cannot drift apart.
*/}}
{{- define "health-check-operator.metricsPort" -}}
{{- splitList ":" .Values.metrics.bindAddress | last -}}
{{- end -}}
