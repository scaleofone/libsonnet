{
  local k = import 'github.com/jsonnet-libs/k8s-libsonnet/main.libsonnet',
  local Pod = k.core.v1.pod,
  local Container = k.core.v1.container,
  local ContainerPort = k.core.v1.containerPort,
  local VolumeMount = k.core.v1.volumeMount,
  local StatefulSet = k.apps.v1.statefulSet,
  local PersistentVolumeClaimTemplate = k.core.v1.persistentVolumeClaimTemplate,
  local Service = k.core.v1.service,
  local ServicePort = k.core.v1.servicePort,
  local Secret = k.core.v1.secret,

  StatefulPostgres:: {
    service: '',
    factory:: function(squareName, square) {
      assert std.objectHas(square, 'dbName'),
      assert std.objectHas(square, 'dbUser'),
      assert std.objectHas(square, 'dbPassword'),

      local serviceName = if std.objectHas(square, 'serviceName') then square.serviceName else squareName,
      local volumeName = squareName+'_data',
      local containerPort = 5432,

      statefulSet: StatefulSet.new(squareName, containers=[
          Container.new('postgres', 'postgres:9.6')
            + Container.withPorts([
              ContainerPort.new(containerPort)
            ])
            + Container.withEnvMap({
              POSTGRES_DB: square.dbName,
              POSTGRES_USER: square.dbUser,
              POSTGRES_PASSWORD: square.dbPassword,
            })
            + Container.withVolumeMounts([
              VolumeMount.new(volumeName, '/var/lib/postgresql/data')
                + VolumeMount.withSubPath('postgres')
            ])
        ])
        + StatefulSet.spec.withVolumeClaimTemplates([
          PersistentVolumeClaimTemplate.metadata.withName(volumeName)
            + PersistentVolumeClaimTemplate.spec.withAccessModes(['ReadWriteOnce'])
            + PersistentVolumeClaimTemplate.spec.resources.withRequests({ storage: '2Gi' })
        ])
        + StatefulSet.spec.withServiceName(serviceName)
      ,

      service: Service.new(serviceName, self.statefulSet.spec.selector.matchLabels, [
        ServicePort.new(containerPort, containerPort)
      ]),

    },
  },

  StatelessPostgres:: {
    service: '',
    factory:: function(squareName, square) {
      assert std.objectHas(square, 'dbName'),
      assert std.objectHas(square, 'dbUser'),
      assert std.objectHas(square, 'dbPassword'),

      local serviceName = if std.objectHas(square, 'serviceName') then square.serviceName else squareName,
      local containerPort = 5432,
      local podName = squareName+'_pod',

      pod: Pod.new(podName)
        + Pod.metadata.withLabels({ name: podName })
        + Pod.spec.withContainers([
          Container.new('postgres', 'postgres:9.6')
            + Container.withPorts([
              ContainerPort.new(containerPort)
            ])
            + Container.withEnvMap({
              POSTGRES_DB: square.dbName,
              POSTGRES_USER: square.dbUser,
              POSTGRES_PASSWORD: square.dbPassword,
            })
        ])
      ,
      service: Service.new(serviceName, self.pod.metadata.labels, [
        ServicePort.new(containerPort, containerPort)
      ]),
    },
  },
}
