{{/* Labels shared by every resource */}}
{{- define "library.labels" -}}
app.kubernetes.io/part-of: library
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/* Selector labels for the app pods */}}
{{- define "library.appSelector" -}}
app.kubernetes.io/name: library-app
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Selector labels for the MySQL pod */}}
{{- define "library.mysqlSelector" -}}
app.kubernetes.io/name: mysql
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}