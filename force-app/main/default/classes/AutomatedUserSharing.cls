public class AutomatedUserSharing {
    @InvocableMethod(label='Create User Sharing Records' description='Creates User sharing records based on the configs from ApexShare Config object')
    public static void createUserShareRecords(List<Id> recordIds){
        //identify object type
        String objName = AutomatedSharingUtilities.findObjectName(recordIds[0]);

        //find the Group Sharing record type
        Id RTId = Schema.SObjectType.ApexShare_Config__c.getRecordTypeInfosByName().get('Share with User').getRecordTypeId();

        //get the ApexShare_Config object details
        Map<Id, ApexShare_Config__c> idShareConfigs = new MAP<Id, ApexShare_Config__c>([SELECT Id, 
                                                        Object_API_Name__c, 
                                                        Access__c,
                                                        RecordTypeId, 
                                                        Lookup_API_Name__c,
                                                        Criteria_Field_Name__c,
                                                        Criteria_Field_Value__c,
                                                        Group_Role_ID__c,
                                                        Apex_Sharing_Reason__c 
                                                        FROM ApexShare_Config__c 
                                                        WHERE Object_API_Name__c = :objName AND RecordTypeId = :RTId AND Active__c = TRUE]);

        if(idShareConfigs.keySet().size()>0){
            //match SObject record id with respective ApexShare_Config records
            Map<Id, List<ApexShare_Config__c>> recordIdShareConfigs = new Map<Id, List<ApexShare_Config__c>>();
            Set<String> sharingReasons = new Set<String>();
            Set<String> fieldAPINames = new Set<String>();
            for(Id recordId: recordIds){
                List<ApexShare_Config__c> apexSCList= new List<ApexShare_Config__c>();
                for(ApexShare_Config__c apexSC: idShareConfigs.values()){
                    if(apexSC.Apex_Sharing_Reason__c != NULL) sharingReasons.add(apexSC.Apex_Sharing_Reason__c);
                    if(apexSC.Criteria_Field_Name__c != NULL) fieldAPINames.add(apexSC.Criteria_Field_Name__c);
                    if(apexSC.Lookup_API_Name__c != NULL) fieldAPINames.add(apexSC.Lookup_API_Name__c);
                    apexScList.add(apexSC);
                }
                recordIdShareConfigs.put(recordId, apexScList);
            }
        
            //for every record and its user share configs, create a map and populate recordsharewithuser apex object
            List<String> newList = new List<String>(fieldAPINames);
            String fieldAPINamesString = String.join(newList, ',');
            Map<Id, List<RecordShareWithUser>> recordIdUserShareData = new Map<Id, List<RecordShareWithUser>>();
            Set<id> keySet = recordIdShareConfigs.keyset();
            String queryString = 'SELECT Id, '+ fieldAPINamesString +' FROM '+ objName +' WHERE Id IN :keySet';
            System.debug('SOQL Query ' + queryString);
            Map<Id, SObject> recordIdSobjects = new Map<Id, SObject>(Database.query(queryString));
    
            for(Id recordId: keySet){
                List<RecordShareWithUser> RSWUList = new List<RecordShareWithUser>(); 
                for(ApexShare_Config__c apexSC: recordIdShareConfigs.get(recordId)){
                    if(recordIdSobjects.get(recordId).get(apexSC.Lookup_API_Name__c) != null){
                        RecordShareWithUser RSWU = new RecordShareWithUser();
                        //assign values
                        RSWU.recordId = recordId;
                        RSWU.ObjectAPIName = objName;
                        RSWU.apexSCId = apexSC.Id;
                        RSWU.accessLevel = apexSC.Access__c;
                        RSWU.sharingReason = apexSC.Apex_Sharing_Reason__c;
                        RSWU.lookupAPIname = apexSC.Lookup_API_Name__c;
                        RSWU.criteriaFieldName = apexSC.Criteria_Field_Name__c;
                        RSWU.criteriaFieldValue = apexSC.Criteria_Field_Value__c;
                        Id userId = (Id)recordIdSobjects.get(recordId).get(apexSC.Lookup_API_Name__c);
                        RSWU.LookupUserId = userId;
                        System.debug('The lookup api name: ' + apexSC.Lookup_API_Name__c);
                        if(apexSC.Lookup_API_Name__c != NULL) System.debug('The lookup api name: ' + apexSC.Lookup_API_Name__c + ' and its value is: '+  recordIdSobjects.get(recordId).get(apexSC.Lookup_API_Name__c));
                        RSWUList.add(RSWU);
                    } 
                }
                recordIdUserShareData.put(recordId, RSWUList);
            }

            //delete existing share records for the same user for the same record
            AutomatedSharingUtilities.deleteShareRecords(recordIds, sharingReasons);
            
            //generate instances of share records for users
            List<SObject> shareRecords = new List<SObject>();
            for(Id recordId: recordIdUserShareData.keyset()){
                for(RecordShareWithUser rswu: recordIdUserShareData.get(recordId)){
                    // use criteria if it is provided in the config object
                    String criteriaValue = NULL;
                    if(rswu.criteriaFieldName != NULL){
                        criteriaValue = (String)recordIdSobjects.get(recordId).get(rswu.criteriaFieldName);
                        if(rswu.criteriaFieldValue == criteriaValue && criteriaValue != NULL){
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
                    else {
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
            }

            //Create share records
            AutomatedSharingUtilities.insertShareRecords(shareRecords);
        }
    }

    //apex data object to store recordId, LookupAPI, and the corresponding UserId
    public class RecordShareWithUser{
        Id recordId = NULL;
        String ObjectAPIName = NULL;
        Id apexSCId = NULL;
        String accessLevel = NULL;
        String lookupAPIname = NULL;
        String criteriaFieldName = NULL;
        String criteriaFieldValue = NULL;
        Id lookupUserId = NULL;
        String sharingReason = NULL;
    }
}