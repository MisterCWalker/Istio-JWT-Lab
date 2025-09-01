{{- define "jwt-demo-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "jwt-demo-app.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "jwt-demo-app.labels" -}}
app.kubernetes.io/name: {{ include "jwt-demo-app.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{- define "jwt-demo-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jwt-demo-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}