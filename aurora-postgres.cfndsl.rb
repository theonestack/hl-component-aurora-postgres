CloudFormation do

  Condition("UseSnapshotID", FnNot(FnEquals(Ref(:SnapshotID), '')))
  Condition("CreateHostRecord", FnNot(FnEquals(Ref(:DnsDomain), '')))
  Condition("UseGlobalClusterIdentifier", FnNot(FnEquals(Ref(:GlobalClusterIdentifier), '')))
  Condition("UseUsernameAndPassword", FnAnd([FnEquals(Ref(:SnapshotID), ''), FnEquals(Ref(:GlobalClusterIdentifier), '')]))

  aurora_tags = []
  tags = external_parameters.fetch(:tags, {})
  aurora_tags << { Key: 'Name', Value: FnSub("${EnvironmentName}-#{external_parameters[:component_name]}") }
  aurora_tags << { Key: 'Environment', Value: Ref(:EnvironmentName) }
  aurora_tags << { Key: 'EnvironmentType', Value: Ref(:EnvironmentType) }
  aurora_tags.push(*tags.map {|k,v| {Key: k, Value: FnSub(v)}}).uniq { |h| h[:Key] }


  cluster_roles = []
  invoke_lambdas = external_parameters.fetch(:invoke_lambdas, [])

  if invoke_lambdas.any?
    policy = {
      'invoke-lambda' => [
        {
          'action' => ['lambda:InvokeFunction'],
          'resource' => invoke_lambdas.map {|lambda_name| FnSub("arn:aws:lambda:${AWS::Region}:${AWS::AccountId}:function/#{lambda_name}")}
        }
      ]
    }

    IAM_Role(:AuroraLambdaInvokeIAMRole) {
      AssumeRolePolicyDocument service_assume_role_policy('rds')
      Policies iam_role_policies(policy)
    }

    cluster_roles << {
      FeatureName: 'Lambda',
      RoleArn: FnGetAtt(:AuroraLambdaInvokeIAMRole, :Arn)    
    }
  end

  s3_export = external_parameters.fetch(:s3_export, nil)

  if s3_export
    policy = {
      'invoke-lambda' => [
        {
          'action' => ['S3:PutObject'],
          'resource' => FnSub("aws:arn:s3:::#{s3_export}")
        }
      ]
    }

    IAM_Role(:Auroras3ExportIAMRole) {
      AssumeRolePolicyDocument service_assume_role_policy('rds')
      Policies iam_role_policies(policy)
    }

    cluster_roles << {
      FeatureName: 's3Export',
      RoleArn: FnGetAtt(:Auroras3ExportIAMRole, :Arn)    
    }
  end

  s3_import = external_parameters.fetch(:s3_import, nil)

  if s3_import
    policy = {
      'invoke-lambda' => [
        {
          'action' => ['S3:PutObject'],
          'resource' => [
            FnSub("aws:arn:s3:::#{s3_export}"),
            FnSub("aws:arn:s3:::#{s3_export}/*")
          ]
        }
      ]
    }

    IAM_Role(:Auroras3ImportIAMRole) {
      AssumeRolePolicyDocument service_assume_role_policy('rds')
      Policies iam_role_policies(policy)
    }

    cluster_roles << {
      FeatureName: 's3Import',
      RoleArn: FnGetAtt(:Auroras3ImportIAMRole, :Arn)    
    }
  end

  ingress = []
  security_group_rules = external_parameters.fetch(:security_group_rules, [])
  security_group_rules.each do |rule|
    sg_rule = {
      FromPort: cluster_port,
      IpProtocol: 'TCP',
      ToPort: cluster_port,
    }
    if rule['security_group_id']
      if rule['security_group_id'].is_a?(Hash)
        sg_rule['SourceSecurityGroupId'] = rule['security_group_id']
      else
        sg_rule['SourceSecurityGroupId'] = FnSub(rule['security_group_id'])
      end
    else
      if rule['ip'].is_a?(Hash)
        sg_rule['CidrIp'] = rule['ip']
      else
        sg_rule['CidrIp'] = FnSub(rule['ip'])
      end
    end
    if rule['desc']
      sg_rule['Description'] = FnSub(rule['desc'])
    end
    ingress << sg_rule
  end

  EC2_SecurityGroup(:SecurityGroup) do
    VpcId Ref('VPCId')
    GroupDescription FnSub("Aurora postgres #{component_name} access for the ${EnvironmentName} environment")
    SecurityGroupIngress ingress if ingress.any?
    SecurityGroupEgress ([
      {
        CidrIp: "0.0.0.0/0",
        Description: "outbound all for ports",
        IpProtocol: -1,
      }
    ])
    Tags aurora_tags
  end

  Output(:SecurityGroupId) {
    Value(FnGetAtt(:SecurityGroup, :GroupId))
    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-securitygroup-id")
  }

  RDS_DBSubnetGroup(:DBClusterSubnetGroup) {
    SubnetIds Ref('SubnetIds')
    DBSubnetGroupDescription FnSub("Aurora postgres #{component_name} subnets for the ${EnvironmentName} environment")
    Tags aurora_tags
  }

  cluster_parameters = external_parameters.fetch(:cluster_parameters, nil)

  RDS_DBClusterParameterGroup(:DBClusterParameterGroup) {
    Description FnSub("Aurora postgres #{component_name} cluster parameters for the ${EnvironmentName} environment")
    Family family
    Parameters cluster_parameters unless cluster_parameters.nil?
    Tags aurora_tags
  }

  secrets_manager = external_parameters.fetch(:secret_username, false)
  if secrets_manager
    SecretsManager_Secret(:SecretCredentials) {
      GenerateSecretString ({
        SecretStringTemplate: "{\"username\":\"#{secrets_manager}\"}",
        GenerateStringKey: "password",
        ExcludeCharacters: "\"@'`/\\"
      })
    }

    instance_username = FnJoin('', [ '{{resolve:secretsmanager:', Ref(:SecretCredentials), ':SecretString:username}}' ])
    instance_password = FnJoin('', [ '{{resolve:secretsmanager:', Ref(:SecretCredentials), ':SecretString:password}}' ])

    Output(:SecretCredentials) {
      Value(Ref(:SecretCredentials))
      Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-Secret")
    }
  else
    instance_username = FnJoin('', [ '{{resolve:ssm:', FnSub(master_login['username_ssm_param']), ':1}}' ])
    instance_password = FnJoin('', [ '{{resolve:ssm-secure:', FnSub(master_login['password_ssm_param']), ':1}}' ])
  end

  engine_version = external_parameters.fetch(:engine_version, nil)
  engine_mode = external_parameters.fetch(:engine_mode, nil)
  database_name = external_parameters.fetch(:database_name, nil)
  storage_encrypted = external_parameters.fetch(:storage_encrypted, nil)
  kms = external_parameters.fetch(:kms, false)
  cluster_maintenance_window = external_parameters.fetch(:cluster_maintenance_window, nil)
  cloudwatch_log_exports = external_parameters.fetch(:cloudwatch_log_exports, [])
  deletion_protection = external_parameters.fetch(:deletion_protection, nil)
  backup_retention_period = external_parameters.fetch(:backup_retention_period, nil)

  # for serverless v2 the EngineMode property in the DBCluster is to be left unset

  RDS_DBCluster(:DBCluster) {
    Engine 'aurora-postgresql'
    EngineVersion engine_version unless engine_version.nil?
    DBClusterParameterGroupName Ref(:DBClusterParameterGroup)
    EnableCloudwatchLogsExports cloudwatch_log_exports if cloudwatch_log_exports.any?
    PreferredMaintenanceWindow cluster_maintenance_window unless cluster_maintenance_window.nil?
    SnapshotIdentifier FnIf('UseSnapshotID', Ref(:SnapshotID), Ref('AWS::NoValue'))
    MasterUsername  FnIf('UseUsernameAndPassword', instance_username, Ref('AWS::NoValue'))
    MasterUserPassword  FnIf('UseUsernameAndPassword', instance_password, Ref('AWS::NoValue'))
    DBSubnetGroupName Ref(:DBClusterSubnetGroup)
    VpcSecurityGroupIds [ Ref(:SecurityGroup) ]
    DatabaseName FnSub(database_name) unless database_name.nil?
    StorageEncrypted storage_encrypted unless storage_encrypted.nil?
    DeletionProtection deletion_protection unless deletion_protection.nil?
    BackupRetentionPeriod backup_retention_period unless backup_retention_period.nil?
    KmsKeyId Ref('KmsKeyId') if kms
    Port external_parameters[:cluster_port]
    Tags aurora_tags
    AssociatedRoles cluster_roles if cluster_roles.any?
    GlobalClusterIdentifier FnIf('UseGlobalClusterIdentifier', Ref('GlobalClusterIdentifier'), Ref('AWS::NoValue'))

    if engine_mode == 'serverless'
      EnableHttpEndpoint Ref(:EnableHttpEndpoint)
      ServerlessV2ScalingConfiguration({
        MinCapacity: Ref('MinCapacity'),
        MaxCapacity: Ref('MaxCapacity')
      })
    end
  }

  instance_parameters = external_parameters.fetch(:instance_parameters, nil)

  RDS_DBParameterGroup(:DBInstanceParameterGroup) {
    Description FnSub("Aurora postgres #{component_name} instance parameters for the ${EnvironmentName} environment")
    Family family
    Parameters instance_parameters unless instance_parameters.nil?
    Tags aurora_tags
  }

  minor_upgrade = external_parameters.fetch(:minor_upgrade, nil)
  maint_window = external_parameters.fetch(:maint_window, nil) # key kept for backwards compatibility
  writer_maintenance_window = external_parameters.fetch(:writer_maintenance_window, maint_window)

  Condition(:EnableEnhancedMonitoring, FnNot(FnEquals(Ref(:EnhancedMonitoringInterval), '0')))

  IAM_Role(:EnhancedMonitoringRole) {
    Condition(:EnableEnhancedMonitoring)
    AssumeRolePolicyDocument service_assume_role_policy('monitoring.rds')
    ManagedPolicyArns ['arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole']
  }

  if engine_mode == 'serverless'
    RDS_DBInstance(:ServerlessDBInstance) {
      Engine 'aurora-postgresql'
      DBInstanceClass 'db.serverless'
      DBClusterIdentifier Ref(:DBCluster)
      MonitoringInterval FnIf(:EnableEnhancedMonitoring, Ref(:EnhancedMonitoringInterval), Ref('AWS::NoValue'))
      MonitoringRoleArn FnIf(:EnableEnhancedMonitoring, FnGetAtt(:EnhancedMonitoringRole, :Arn), Ref('AWS::NoValue'))
    }

  else
    Condition("CreateReaderRecord", FnAnd([FnEquals(Ref("EnableReader"), 'true'), Condition('CreateHostRecord')]))
    Condition("EnableReader", FnEquals(Ref("EnableReader"), 'true'))

    RDS_DBInstance(:DBClusterInstanceWriter) {
      DBSubnetGroupName Ref(:DBClusterSubnetGroup)
      DBParameterGroupName Ref(:DBInstanceParameterGroup)
      DBClusterIdentifier Ref(:DBCluster)
      Engine 'aurora-postgresql'
      EngineVersion engine_version unless engine_version.nil?
      AutoMinorVersionUpgrade minor_upgrade unless minor_upgrade.nil?
      PreferredMaintenanceWindow writer_maintenance_window unless writer_maintenance_window.nil?
      PubliclyAccessible 'false'
      DBInstanceClass Ref(:WriterInstanceType)
      MonitoringInterval FnIf(:EnableEnhancedMonitoring, Ref(:EnhancedMonitoringInterval), Ref('AWS::NoValue'))
      MonitoringRoleArn FnIf(:EnableEnhancedMonitoring, FnGetAtt(:EnhancedMonitoringRole, :Arn), Ref('AWS::NoValue'))
      Tags aurora_tags
    }

    reader_maintenance_window = external_parameters.fetch(:reader_maintenance_window, nil)

    RDS_DBInstance(:DBClusterInstanceReader) {
      Condition(:EnableReader)
      DBSubnetGroupName Ref(:DBClusterSubnetGroup)
      DBParameterGroupName Ref(:DBInstanceParameterGroup)
      DBClusterIdentifier Ref(:DBCluster)
      Engine 'aurora-postgresql'
      EngineVersion engine_version unless engine_version.nil?
      AutoMinorVersionUpgrade minor_upgrade unless minor_upgrade.nil?
      PreferredMaintenanceWindow reader_maintenance_window unless reader_maintenance_window.nil?
      PubliclyAccessible 'false'
      DBInstanceClass Ref(:ReaderInstanceType)
      MonitoringInterval FnIf(:EnableEnhancedMonitoring, Ref(:EnhancedMonitoringInterval), Ref('AWS::NoValue'))
      MonitoringRoleArn FnIf(:EnableEnhancedMonitoring, FnGetAtt(:EnhancedMonitoringRole, :Arn), Ref('AWS::NoValue'))
      Tags aurora_tags
    }

    Route53_RecordSet(:DBClusterReaderRecord) {
      Condition(:CreateReaderRecord)
      HostedZoneName FnSub("#{external_parameters[:dns_format]}.")
      Name FnSub("#{external_parameters[:hostname_read_endpoint]}.#{external_parameters[:dns_format]}.")
      Type 'CNAME'
      TTL '60'
      ResourceRecords [ FnGetAtt('DBCluster','ReadEndpoint.Address') ]
    }
  end

  Route53_RecordSet(:DBHostRecord) {
    Condition(:CreateHostRecord)
    HostedZoneName FnSub("#{external_parameters[:dns_format]}.")
    Name FnSub("#{external_parameters[:hostname]}.#{external_parameters[:dns_format]}.")
    Type 'CNAME'
    TTL '60'
    ResourceRecords [ FnGetAtt('DBCluster','Endpoint.Address') ]
  }

  registry = {}
  service_discovery = external_parameters.fetch(:service_discovery, {})

  unless service_discovery.empty?
    ServiceDiscovery_Service(:ServiceRegistry) {
      NamespaceId Ref(:NamespaceId)
      Name service_discovery['name']  if service_discovery.has_key? 'name'
      DnsConfig({
        DnsRecords: [{
          TTL: 60,
          Type: 'CNAME'
        }],
        RoutingPolicy: 'WEIGHTED'
      })
      if service_discovery.has_key? 'healthcheck'
        HealthCheckConfig service_discovery['healthcheck']
      else
        HealthCheckCustomConfig ({ FailureThreshold: (service_discovery['failure_threshold'] || 1) })
      end
    }

    ServiceDiscovery_Instance(:RegisterInstance) {
      InstanceAttributes(
        AWS_INSTANCE_CNAME: FnGetAtt('DBCluster','Endpoint.Address')
      )
      ServiceId Ref(:ServiceRegistry)
    }

    Output(:ServiceRegistry) {
      Value(Ref(:ServiceRegistry))
      Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-CloudMapService")
    }
  end

  Output(:DBClusterId) {
    Value(Ref(:DBCluster))
    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-dbcluster-id")
  }

end
