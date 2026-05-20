require 'yaml'

describe 'compiled component aurora-postgres' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/deletion_protection.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/deletion_protection/aurora-postgres.compiled.yaml") }
  
  context "Resource" do

    
    context "SecurityGroup" do
      let(:resource) { template["Resources"]["SecurityGroup"] }

      it "is of type AWS::EC2::SecurityGroup" do
          expect(resource["Type"]).to eq("AWS::EC2::SecurityGroup")
      end
      
      it "to have property VpcId" do
          expect(resource["Properties"]["VpcId"]).to eq({"Ref"=>"VPCId"})
      end
      
      it "to have property GroupDescription" do
          expect(resource["Properties"]["GroupDescription"]).to eq({"Fn::Sub"=>"Aurora postgres aurora-postgres access for the ${EnvironmentName} environment"})
      end
      
      it "to have property SecurityGroupEgress" do
          expect(resource["Properties"]["SecurityGroupEgress"]).to eq([{"CidrIp"=>"0.0.0.0/0", "Description"=>"outbound all for ports", "IpProtocol"=>-1}])
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-aurora-postgres"}}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "DBClusterSubnetGroup" do
      let(:resource) { template["Resources"]["DBClusterSubnetGroup"] }

      it "is of type AWS::RDS::DBSubnetGroup" do
          expect(resource["Type"]).to eq("AWS::RDS::DBSubnetGroup")
      end
      
      it "to have property SubnetIds" do
          expect(resource["Properties"]["SubnetIds"]).to eq({"Ref"=>"SubnetIds"})
      end
      
      it "to have property DBSubnetGroupDescription" do
          expect(resource["Properties"]["DBSubnetGroupDescription"]).to eq({"Fn::Sub"=>"Aurora postgres aurora-postgres subnets for the ${EnvironmentName} environment"})
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-aurora-postgres"}}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "DBClusterParameterGroup" do
      let(:resource) { template["Resources"]["DBClusterParameterGroup"] }

      it "is of type AWS::RDS::DBClusterParameterGroup" do
          expect(resource["Type"]).to eq("AWS::RDS::DBClusterParameterGroup")
      end
      
      it "to have property Description" do
          expect(resource["Properties"]["Description"]).to eq({"Fn::Sub"=>"Aurora postgres aurora-postgres cluster parameters for the ${EnvironmentName} environment"})
      end
      
      it "to have property Family" do
          expect(resource["Properties"]["Family"]).to eq("aurora-postgresql12")
      end
      
      it "to have property Parameters" do
          expect(resource["Properties"]["Parameters"]).to eq({"timezone"=>"UTC"})
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-aurora-postgres"}}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "DBCluster" do
      let(:resource) { template["Resources"]["DBCluster"] }

      it "is of type AWS::RDS::DBCluster" do
          expect(resource["Type"]).to eq("AWS::RDS::DBCluster")
      end
      
      it "to have property Engine" do
          expect(resource["Properties"]["Engine"]).to eq("aurora-postgresql")
      end
      
      it "to have property EngineVersion" do
          expect(resource["Properties"]["EngineVersion"]).to eq(12.1)
      end
      
      it "to have property DBClusterParameterGroupName" do
          expect(resource["Properties"]["DBClusterParameterGroupName"]).to eq({"Ref"=>"DBClusterParameterGroup"})
      end
      
      it "to have property DeletionProtection" do
          expect(resource["Properties"]["DeletionProtection"]).to eq(true)
      end
      
      it "to have property SnapshotIdentifier" do
          expect(resource["Properties"]["SnapshotIdentifier"]).to eq({"Fn::If"=>["UseSnapshotID", {"Ref"=>"SnapshotID"}, {"Ref"=>"AWS::NoValue"}]})
      end
      
      it "to have property MasterUsername" do
          expect(resource["Properties"]["MasterUsername"]).to eq({"Fn::If"=>["UseUsernameAndPassword", {"Fn::Join"=>["", ["{{resolve:ssm:", {"Fn::Sub"=>"/rds/AURORA_POSTGRES_MASTER_USERNAME"}, ":1}}"]]}, {"Ref"=>"AWS::NoValue"}]})
      end
      
      it "to have property MasterUserPassword" do
          expect(resource["Properties"]["MasterUserPassword"]).to eq({"Fn::If"=>["UseUsernameAndPassword", {"Fn::Join"=>["", ["{{resolve:ssm-secure:", {"Fn::Sub"=>"/rds/AURORA_POSTGRES_MASTER_PASSWORD"}, ":1}}"]]}, {"Ref"=>"AWS::NoValue"}]})
      end
      
      it "to have property DBSubnetGroupName" do
          expect(resource["Properties"]["DBSubnetGroupName"]).to eq({"Ref"=>"DBClusterSubnetGroup"})
      end
      
      it "to have property VpcSecurityGroupIds" do
          expect(resource["Properties"]["VpcSecurityGroupIds"]).to eq([{"Ref"=>"SecurityGroup"}])
      end
      
      it "to have property Port" do
          expect(resource["Properties"]["Port"]).to eq(5432)
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-aurora-postgres"}}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "DBInstanceParameterGroup" do
      let(:resource) { template["Resources"]["DBInstanceParameterGroup"] }

      it "is of type AWS::RDS::DBParameterGroup" do
          expect(resource["Type"]).to eq("AWS::RDS::DBParameterGroup")
      end
      
      it "to have property Description" do
          expect(resource["Properties"]["Description"]).to eq({"Fn::Sub"=>"Aurora postgres aurora-postgres instance parameters for the ${EnvironmentName} environment"})
      end
      
      it "to have property Family" do
          expect(resource["Properties"]["Family"]).to eq("aurora-postgresql12")
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-aurora-postgres"}}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "DBClusterInstanceWriter" do
      let(:resource) { template["Resources"]["DBClusterInstanceWriter"] }

      it "is of type AWS::RDS::DBInstance" do
          expect(resource["Type"]).to eq("AWS::RDS::DBInstance")
      end
      
      it "to have property DBSubnetGroupName" do
          expect(resource["Properties"]["DBSubnetGroupName"]).to eq({"Ref"=>"DBClusterSubnetGroup"})
      end
      
      it "to have property DBParameterGroupName" do
          expect(resource["Properties"]["DBParameterGroupName"]).to eq({"Ref"=>"DBInstanceParameterGroup"})
      end
      
      it "to have property DBClusterIdentifier" do
          expect(resource["Properties"]["DBClusterIdentifier"]).to eq({"Ref"=>"DBCluster"})
      end
      
      it "to have property Engine" do
          expect(resource["Properties"]["Engine"]).to eq("aurora-postgresql")
      end
      
      it "to have property EngineVersion" do
          expect(resource["Properties"]["EngineVersion"]).to eq(12.1)
      end
      
      it "to have property AutoMinorVersionUpgrade" do
          expect(resource["Properties"]["AutoMinorVersionUpgrade"]).to eq(false)
      end
      
      it "to have property PubliclyAccessible" do
          expect(resource["Properties"]["PubliclyAccessible"]).to eq("false")
      end
      
      it "to have property DBInstanceClass" do
          expect(resource["Properties"]["DBInstanceClass"]).to eq({"Ref"=>"WriterInstanceType"})
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-aurora-postgres"}}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "DBClusterInstanceReader" do
      let(:resource) { template["Resources"]["DBClusterInstanceReader"] }

      it "is of type AWS::RDS::DBInstance" do
          expect(resource["Type"]).to eq("AWS::RDS::DBInstance")
      end
      
      it "to have property DBSubnetGroupName" do
          expect(resource["Properties"]["DBSubnetGroupName"]).to eq({"Ref"=>"DBClusterSubnetGroup"})
      end
      
      it "to have property DBParameterGroupName" do
          expect(resource["Properties"]["DBParameterGroupName"]).to eq({"Ref"=>"DBInstanceParameterGroup"})
      end
      
      it "to have property DBClusterIdentifier" do
          expect(resource["Properties"]["DBClusterIdentifier"]).to eq({"Ref"=>"DBCluster"})
      end
      
      it "to have property Engine" do
          expect(resource["Properties"]["Engine"]).to eq("aurora-postgresql")
      end
      
      it "to have property EngineVersion" do
          expect(resource["Properties"]["EngineVersion"]).to eq(12.1)
      end
      
      it "to have property AutoMinorVersionUpgrade" do
          expect(resource["Properties"]["AutoMinorVersionUpgrade"]).to eq(false)
      end
      
      it "to have property PubliclyAccessible" do
          expect(resource["Properties"]["PubliclyAccessible"]).to eq("false")
      end
      
      it "to have property DBInstanceClass" do
          expect(resource["Properties"]["DBInstanceClass"]).to eq({"Ref"=>"ReaderInstanceType"})
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-aurora-postgres"}}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "DBClusterReaderRecord" do
      let(:resource) { template["Resources"]["DBClusterReaderRecord"] }

      it "is of type AWS::Route53::RecordSet" do
          expect(resource["Type"]).to eq("AWS::Route53::RecordSet")
      end
      
      it "to have property HostedZoneName" do
          expect(resource["Properties"]["HostedZoneName"]).to eq({"Fn::Sub"=>"${EnvironmentName}.${DnsDomain}."})
      end
      
      it "to have property Name" do
          expect(resource["Properties"]["Name"]).to eq({"Fn::Sub"=>"aurora2pg-read.${EnvironmentName}.${DnsDomain}."})
      end
      
      it "to have property Type" do
          expect(resource["Properties"]["Type"]).to eq("CNAME")
      end
      
      it "to have property TTL" do
          expect(resource["Properties"]["TTL"]).to eq("60")
      end
      
      it "to have property ResourceRecords" do
          expect(resource["Properties"]["ResourceRecords"]).to eq([{"Fn::GetAtt"=>["DBCluster", "ReadEndpoint.Address"]}])
      end
      
    end
    
    context "DBHostRecord" do
      let(:resource) { template["Resources"]["DBHostRecord"] }

      it "is of type AWS::Route53::RecordSet" do
          expect(resource["Type"]).to eq("AWS::Route53::RecordSet")
      end
      
      it "to have property HostedZoneName" do
          expect(resource["Properties"]["HostedZoneName"]).to eq({"Fn::Sub"=>"${EnvironmentName}.${DnsDomain}."})
      end
      
      it "to have property Name" do
          expect(resource["Properties"]["Name"]).to eq({"Fn::Sub"=>"aurora2pg.${EnvironmentName}.${DnsDomain}."})
      end
      
      it "to have property Type" do
          expect(resource["Properties"]["Type"]).to eq("CNAME")
      end
      
      it "to have property TTL" do
          expect(resource["Properties"]["TTL"]).to eq("60")
      end
      
      it "to have property ResourceRecords" do
          expect(resource["Properties"]["ResourceRecords"]).to eq([{"Fn::GetAtt"=>["DBCluster", "Endpoint.Address"]}])
      end
      
    end
    
  end

end
