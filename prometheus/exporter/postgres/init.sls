{% from "prometheus/map.jinja" import prometheus with context %}

include:
  - prometheus.user

postgres_exporter_tarball:
  archive.extracted:
    - name: {{ prometheus.exporter.postgres.install_dir }}
    - source: {{ prometheus.exporter.postgres.source }}
    - source_hash: {{ prometheus.exporter.postgres.source_hash }}
    - user: {{ prometheus.user }}
    - group: {{ prometheus.group }}
    - archive_format: tar
    - if_missing: {{ prometheus.exporter.postgres.version_path }}

postgres_exporter_bin_link:
  file.symlink:
    - name: /usr/bin/postgres_exporter
    - target: {{ prometheus.exporter.postgres.version_path }}/postgres_exporter
    - require:
      - archive: postgres_exporter_tarball

postgres_exporter_defaults:
  file.managed:
    - name: /etc/default/postgres_exporter
    - source: salt://prometheus/files/default-postgres_exporter.jinja
    - template: jinja
    - defaults:
        listen_address: {{ prometheus.exporter.postgres.listen_address }}

postgres_exporter_service_unit:
  file.managed:
{%- if grains.get('init') == 'systemd' %}
    - name: /etc/systemd/system/postgres_exporter.service
    - source: salt://prometheus/files/postgres_exporter.systemd.jinja
{%- elif grains.get('init') == 'upstart' %}
    - name: /etc/init/postgres_exporter.conf
    - source: salt://prometheus/files/postgres_exporter.upstart.jinja
{%- elif grains.get('init') == 'sysvinit' %}
    - name: /etc/init.d/postgres_exporter
    - source: salt://prometheus/files/sysvinit.jinja
    - template: jinja
    - mode: 0744
    - context: 
        daemon_name: node exporter
        description: Prometheus exporter for machine metrics
        bin: /usr/bin/postgres_exporter
        name: postgres_exporter
        user: postgres      
{%- endif %}
    - require_in:
      - file: postgres_exporter_service

postgres_exporter_service:
  service.running:
    - name: postgres_exporter
    - enable: True
    - reload: True
    - watch:
      - file: postgres_exporter_service_unit
      - file: postgres_exporter_defaults
      - file: postgres_exporter_bin_link
      - file: postgres_exporter_queries

postgres_exporter_queries:
  file.managed:
    - name: /etc/postgresql/queries.yaml
    - source: salt://prometheus/exporter/postgres/files/queries.yaml
    - user: postgres
    - group: postgres
    - mode: 0644