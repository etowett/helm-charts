{{/*
Expand the name of the chart.
*/}}
{{- define "cron.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cron.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cron.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cron.labels" -}}
helm.sh/chart: {{ include "cron.chart" . }}
{{ include "cron.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cron.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cron.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Normalize a cronjobs map key into a DNS-1123 label (lowercase alphanumerics and '-'),
so resource names, container names, and label values are always valid regardless of how
the key was written (e.g. "Nightly_Cleanup" -> "nightly-cleanup").
*/}}
{{- define "cron.jobName" -}}
{{- $n := regexReplaceAll "[^a-z0-9]+" (lower .) "-" -}}
{{- $n | trimAll "-" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "cron.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cron.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" (default .Values.serviceAccount.name .Values.serviceAccountName) }}
{{- end }}
{{- end }}

{{/*
cron.merged — compute the effective configuration for a single cronjob entry.
Takes a dict {root, job}. Returns YAML of the shared defaults deep-merged with the per-job
override (the per-job value wins). Release-scoped keys (serviceAccount, helper resources, the
cronjobs map itself) are excluded so they are never merged into an individual job.
*/}}
{{- define "cron.merged" -}}
{{- $shared := omit .root.Values "nameOverride" "fullnameOverride" "serviceAccount" "configMaps" "externalSecrets" "pvc" "networkPolicy" "rbac" "cronjobs" -}}
{{- merge (deepCopy .job) (deepCopy $shared) | toYaml -}}
{{- end -}}

{{/*
cron.probe — render the body of a probe (httpGet|tcpSocket|exec|grpc + threshold fields).
Takes the probe dict as the context. Used for native sidecar probes.
*/}}
{{- define "cron.probe" -}}
{{- $probe := . -}}
{{- if .httpGet }}
httpGet:
  {{- toYaml .httpGet | nindent 2 }}
{{- else if .tcpSocket }}
tcpSocket:
  {{- toYaml .tcpSocket | nindent 2 }}
{{- else if .exec }}
exec:
  {{- toYaml .exec | nindent 2 }}
{{- else if .grpc }}
grpc:
  {{- toYaml .grpc | nindent 2 }}
{{- end }}
{{- range $field := list "initialDelaySeconds" "periodSeconds" "timeoutSeconds" "successThreshold" "failureThreshold" }}
{{- if hasKey $probe $field }}
{{ $field }}: {{ index $probe $field }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
cron.podSpec — render the pod template spec body for a cronjob.
Takes a dict {root, cfg, name} where cfg is the merged configuration from cron.merged.
*/}}
{{- define "cron.podSpec" -}}
{{- $root := .root -}}
{{- $cfg := .cfg -}}
{{- $name := .name -}}
restartPolicy: {{ $cfg.job.restartPolicy | default "OnFailure" }}
serviceAccountName: {{ $cfg.serviceAccountName | default (include "cron.serviceAccountName" $root) }}
automountServiceAccountToken: {{ $root.Values.serviceAccount.automount }}
{{- with $cfg.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $cfg.priorityClassName }}
priorityClassName: {{ . }}
{{- end }}
{{- with $cfg.runtimeClassName }}
runtimeClassName: {{ . }}
{{- end }}
{{- if not (kindIs "invalid" $cfg.terminationGracePeriodSeconds) }}
terminationGracePeriodSeconds: {{ $cfg.terminationGracePeriodSeconds | int64 }}
{{- end }}
{{- with $cfg.podSecurityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $cfg.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if or $cfg.sidecars $cfg.initContainer.enabled }}
initContainers:
  {{- range $sidecar := $cfg.sidecars }}
  - name: {{ $sidecar.name }}
    image: "{{ required (printf "sidecars[%s].image.repository is required" $sidecar.name) $sidecar.image.repository }}:{{ required (printf "sidecars[%s].image.tag is required" $sidecar.name) $sidecar.image.tag }}"
    imagePullPolicy: {{ $sidecar.image.pullPolicy | default "IfNotPresent" }}
    restartPolicy: Always
    {{- with (or $sidecar.commands $sidecar.command) }}
    command:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $sidecar.args }}
    args:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- if or $sidecar.env $sidecar.secretEnv }}
    env:
    {{- range $sidecar.env }}
      - name: {{ .name }}
        {{- if hasKey . "value" }}
        value: {{ .value | quote }}
        {{- else if .valueFrom }}
        valueFrom:
          {{- toYaml .valueFrom | nindent 10 }}
        {{- end }}
    {{- end }}
    {{- range $sidecar.secretEnv }}
      - name: {{ .name }}
        valueFrom:
          {{- toYaml .valueFrom | nindent 10 }}
    {{- end }}
    {{- end }}
    {{- with $sidecar.ports }}
    ports:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $sidecar.securityContext }}
    securityContext:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $sidecar.resources }}
    resources:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $sidecar.volumeMounts }}
    volumeMounts:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $sidecar.startupProbe }}
    startupProbe:
      {{- include "cron.probe" . | trim | nindent 6 }}
    {{- end }}
    {{- with $sidecar.livenessProbe }}
    livenessProbe:
      {{- include "cron.probe" . | trim | nindent 6 }}
    {{- end }}
    {{- with $sidecar.readinessProbe }}
    readinessProbe:
      {{- include "cron.probe" . | trim | nindent 6 }}
    {{- end }}
  {{- end }}
  {{- if $cfg.initContainer.enabled }}
  - name: {{ $cfg.initContainer.name }}
    image: "{{ $cfg.image.repository }}:{{ $cfg.image.tag | default $root.Chart.AppVersion }}"
    imagePullPolicy: {{ $cfg.image.pullPolicy }}
    {{- with $cfg.initContainer.commands }}
    command:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $cfg.initContainer.args }}
    args:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- if or $cfg.env $cfg.secretEnv }}
    env:
    {{- range $k, $v := $cfg.env }}
      - name: {{ $k | quote }}
        value: {{ $v | quote }}
    {{- end }}
    {{- range $k, $v := $cfg.secretEnv }}
      - name: {{ $k | quote }}
        valueFrom:
          secretKeyRef:
          {{- range $kk, $vv := $v }}
            {{ $kk }}: {{ $vv }}
          {{- end }}
    {{- end }}
    {{- end }}
    {{- with $cfg.initContainer.resources }}
    resources:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $cfg.initContainer.volumeMounts }}
    volumeMounts:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- end }}
{{- end }}
containers:
  - name: {{ $name }}
    image: "{{ $cfg.image.repository }}:{{ $cfg.image.tag | default $root.Chart.AppVersion }}"
    imagePullPolicy: {{ $cfg.image.pullPolicy }}
    {{- with $cfg.commands }}
    command:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $cfg.args }}
    args:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $cfg.workingDir }}
    workingDir: {{ . }}
    {{- end }}
    {{- with $cfg.securityContext }}
    securityContext:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- if or $cfg.env $cfg.secretEnv }}
    env:
    {{- range $k, $v := $cfg.env }}
      - name: {{ $k | quote }}
        value: {{ $v | quote }}
    {{- end }}
    {{- range $k, $v := $cfg.secretEnv }}
      - name: {{ $k | quote }}
        valueFrom:
          secretKeyRef:
          {{- range $kk, $vv := $v }}
            {{ $kk }}: {{ $vv }}
          {{- end }}
    {{- end }}
    {{- end }}
    {{- with $cfg.envFrom }}
    envFrom:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $cfg.resources }}
    resources:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $cfg.lifecycle }}
    lifecycle:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $cfg.volumeMounts }}
    volumeMounts:
      {{- toYaml . | nindent 6 }}
    {{- end }}
{{- with $cfg.volumes }}
volumes:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $cfg.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $cfg.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $cfg.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
