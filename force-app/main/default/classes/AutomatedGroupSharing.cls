public class AutomatedGroupSharing {
    @InvocableMethod(label='Create Public Group Sharing Records' description='Creates public group sharing records based on the configs from ApexShare Config object')
    public static void createGroupShareRecords(List<Id> recordIds){
        //identify object type
        Schema.SObjectType token = recordIds[0].getSobjectType();
        Schema.DescribeSObjectResult objResult = token.getDescribe();
        String objName = objResult.getName();

        Id RTId = Schema.SObjectType.ApexShare_Config__c.getRecordTypeInfosByName().get('Share with Public Group').getRecordTypeId();

        //get the ApexShare_Config object details
        Map<Id, ApexShare_Config__c> idShareConfigs = new MAP<Id, ApexShare_Config__c>([SELECT Id, 
                                                        Object_API_Name__c, 
                                                        Access__c,
                                                        RecordTypeId, 
                                                        Lookup_API_Name__c, 
                                                        Group_Role_ID__c,
                                                        Apex_Sharing_Reason__c 
                                                        FROM ApexShare_Config__c 
                                                        WHERE Object_API_Name__c = :objName AND RecordTypeId = :RTId]);

        //match SObject record id with respective ApexShare_Config records
        Map<Id, List<ApexShare_Config__c>> recordIdShareConfigs = new Map<Id, List<ApexShare_Config__c>>();
        for(Id recordId: recordIds){
            List<ApexShare_Config__c> apexScList= new List<ApexShare_Config__c>();
            for(ApexShare_Config__c apexsc: idShareConfigs.values()){
                apexScList.add(apexsc);
            }
            recordIdShareConfigs.put(recordId, apexScList);
        }

        //generate instances of share records for public group
        List<SObject> shareRecords = new List<SObject>();
        for(Id recordId: recordIdShareConfigs.keyset()){
            for(ApexShare_Config__c apexsc: recordIdShareConfigs.get(recordId)){
                if(apexsc.RecordTypeId == Schema.SObjectType.ApexShare_Config__c.getRecordTypeInfosByName().get('Share with Public Group').getRecordTypeId()){
                    Sobject sObj = AutomatedSharingUtilities.createShareObject(
                    apexsc.Object_API_Name__c, 
                    recordId,
                    apexsc.Group_Role_ID__c, 
                    apexsc.Access__c,
                    apexsc.Apex_Sharing_Reason__c
                    );
                shareRecords.add(sObj);
                }
            }
        }

        //Create share records
        AutomatedSharingUtilities.insertShareRecords(shareRecords);

    }
}