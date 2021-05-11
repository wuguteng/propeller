{{/*
Logpath prefix
*/}}
{{- define "propeller.logpathPrefix" -}}
{{ $.Values.labels.language | default "nolan" }}-{{ $.Release.Namespace }}
{{- end -}}

{{/*
Secrets items expand to env
*/}}
{{- define "propeller.expandSecrets" -}}
{{- $secrets := get . "secrets" }}
{{- $secretsRef := get . "ref" }}
{{- if $secrets }}
{{- range $s := $secrets }}
{{- if $s.secret }}
{{- if and $secretsRef $secretsRef.global.secretKeys }}
{{- $refSecrets := $secretsRef.global.secretKeys }}
{{- $sd := get $refSecrets $s.type }}
{{- if $sd }}
{{- range $sk := $sd }}
- name: {{ $s.prefix | upper }}_{{ $sk | upper }}
  valueFrom:
    secretKeyRef:
      name: {{ $s.secret }}
      key: {{ $sk }}
{{- end }}
{{- end }}
{{- end }}
{{- else if $s.configMap }}
{{- if and $secretsRef $secretsRef.global.configMaps }}
{{- $configMaps := $secretsRef.global.configMaps }}
{{- $cm := get $configMaps $s.configMap }}
{{- if $cm }}
{{- range $ck := $cm }}
- name: {{ $s.prefix | upper }}_{{ $ck | upper }}
  valueFrom:
    configMapKeyRef:
      name: {{ $s.configMap }}
      key: {{ $ck }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Env values expand template
*/}}
{{- define "propeller.expandEnv" -}}
{{- $env := . -}}
{{- range $e := $env -}}
{{- if $e.valueFrom }}
- name: {{ $e.name }}
  valueFrom:
  {{- range $ek, $ev := $e.valueFrom }}
    {{ $ek }}:
      {{- range $esk, $esv := $ev }}
      {{ $esk }}: {{ $esv }}
      {{- end }}
  {{- end }}
{{- else }}
- name: {{ $e.name }}
  value: "{{ $e.value }}"
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Env values expand template
*/}}
{{- define "propeller.checkConnectionBySecrets" -}}
{{- $addresses := "" }}
{{- $secrets := get . "secrets" }}
{{- $secretsRef := get . "ref" }}
{{- $container := get . "container" }}
{{- if $secrets }}
{{- range $s := $secrets }}
{{- if $s.secret }}
{{- $envPrefix := $s.prefix | upper }}
{{- if and $secretsRef $secretsRef.global.secretKeys }}
{{- $refSecrets := $secretsRef.global.secretKeys }}
{{- $sd := get $refSecrets $s.secret }}
{{- if $sd }}
{{- $hasHost := has "host" $sd }}
{{- $hasPort := has "port" $sd }}
{{- if and $hasHost $hasPort }}
{{- $envHost := cat "${" $envPrefix "_HOST}" | replace " " "" }}
{{- $envPort := cat "${" $envPrefix "_PORT}" | replace " " "" }}
{{- $addresses = cat $addresses "if nc -w 1" $envHost $envPort "; then sleep 0; else success=false; ping -c 1" $envHost "; echo 'Checking'" $envHost $envPort "'network failed, retrying in next 5 seconds...'; fi;" }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- if ne $addresses "" }}
- name: {{ $container }}-check-network
  image: "busybox"
  imagePullPolicy: IfNotPresent
  command:
  - sh
  - -c
  - "success=false; until ${success}; do success=true; sleep 5;{{ $addresses }} done"
  env:
  {{- range $s := $secrets }}
  {{- if $s.secret }}
  {{- if and $secretsRef $secretsRef.global.secretKeys }}
  {{- $refSecrets := $secretsRef.global.secretKeys }}
  {{- $sd := get $refSecrets $s.secret }}
  {{- if $sd }}
  {{- range $sk := $sd }}
  {{- if or (eq $sk "host") (eq $sk "port") }}
  - name: {{ $s.prefix | upper }}_{{ $sk | upper }}
    valueFrom:
      secretKeyRef:
        name: {{ $s.secret }}
        key: {{ $sk }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- else if $s.configMap }}
  {{- if and $secretsRef $secretsRef.global.configMaps }}
  {{- $configMaps := $secretsRef.global.configMaps }}
  {{- $cm := get $configMaps $s.configMap }}
  {{- if $cm }}
  {{- range $ck := $cm }}
  {{- if or (eq $ck "host") (eq $ck "port") }}
  - name: {{ $s.prefix | upper }}_{{ $ck | upper }}
    valueFrom:
      configMapKeyRef:
        name: {{ $s.configMap }}
        key: {{ $ck }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end -}}
