public class AutomatedUserSharing {
    @InvocableMethod(label='Create User Sharing Records' description='Creates User sharing records based on the configs from ApexShare Config object')
    public static void createUserShareRecords(List<Id> recordIds){
        //identify object type
        Schema.SObjectType token = recordIds[0].getSobjectType();
        Schema.DescribeSObjectResult objResult = token.getDescribe();
        String objName = objResult.getName();

        Id RTId = Schema.SObjectType.ApexShare_Config__c.getRecordTypeInfosByName().get('Share with User').getRecordTypeId();

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

        //get all the user lookup api names to create a dynamic soql
        String lookupApiName = NULL;
        Set<String> lookups = new Set<String>();
        for(ApexShare_Config__c apexSC: idShareConfigs.values()){
            if(apexSC.Lookup_API_Name__c != NULL){
                if(lookupApiName == NULL) lookupApiName = apexSC.Lookup_API_Name__c;
                else lookupApiName = lookupApiName + ', ' + apexSC.Lookup_API_Name__c;
                lookups.add(apexSC.Lookup_API_Name__c);
            }
        }

        //for every record and its share user configs, create a map and populate recordsharewithuser apex object
        Map<Id, List<RecordShareWithUser>> recordIdUserShareData = new Map<Id, List<RecordShareWithUser>>();
        Set<id> keySet = recordIdShareConfigs.keyset();
        String queryString = 'SELECT Id, '+lookupApiName+' FROM '+objName+' WHERE Id IN :keySet';
        System.debug('SOQL Query ' + queryString);
        
        Map<Id, SObject> recordIdSobjects = new Map<Id, SObject>(Database.query(queryString));
        for(Id recordId: keySet){
            List<RecordShareWithUser> RSWUList = new List<RecordShareWithUser>(); 
            for(ApexShare_Config__c apexSC: recordIdShareConfigs.get(recordId)){
                if(apexsc.RecordTypeId == Schema.SObjectType.ApexShare_Config__c.getRecordTypeInfosByName().get('Share with User').getRecordTypeId() && recordIdSobjects.get(recordId).get(apexSC.Lookup_API_Name__c) != null){
                    RecordShareWithUser RSWU = new RecordShareWithUser();
                    //assign values
                    RSWU.recordId = recordId;
                    RSWU.ObjectAPIName = objName;
                    RSWU.apexSCId = apexSC.Id;
                    RSWU.accessLevel = apexSC.Access__c;
                    RSWU.sharingReason = apexSC.Apex_Sharing_Reason__c;
                    RSWU.lookupAPIname = apexSC.Lookup_API_Name__c;
                    RSWU.LookupUserId = (Id)recordIdSobjects.get(recordId).get(apexSC.Lookup_API_Name__c);
                    System.debug('The lookup api name: ' + apexSC.Lookup_API_Name__c);
                    if(apexSC.Lookup_API_Name__c != NULL) System.debug('The lookup api name: ' + apexSC.Lookup_API_Name__c + ' and its value is: '+  recordIdSobjects.get(recordId).get(apexSC.Lookup_API_Name__c));
                    RSWUList.add(RSWU);
                }
                
            }
            recordIdUserShareData.put(recordId, RSWUList);
        }

        //generate instances of share records for users
        List<SObject> shareRecords = new List<SObject>();
        for(Id recordId: recordIdUserShareData.keyset()){
            for(RecordShareWithUser rswu: recordIdUserShareData.get(recordId)){
                Sobject sObj = AutomatedSharingUtilities.createShareObject(
                    rswu.ObjectAPIName, 
                    recordId,
                    rswu.lookupUserId,
                    rswu.accessLevel,
                    rswu.sharingReason
                    );
            shareRecords.add(sObj);
            }
        }

        //Create share records
        AutomatedSharingUtilities.insertShareRecords(shareRecords);
    
    }

    //apex data object to store recordId, LookupAPI, and the corresponding UserId
    public class RecordShareWithUser{
        Id recordId = NULL;
        String ObjectAPIName = NULL;
        Id apexSCId = NULL;
        String accessLevel = NULL;
        String lookupAPIname;
        Id lookupUserId = NULL;
        String sharingReason = NULL;
    }
}