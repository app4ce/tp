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
                                                        Criteria_Field_Name__c,
                                                        Criteria_Field_Value__c, 
                                                        Lookup_API_Name__c, 
                                                        Group_Role_ID__c,
                                                        Apex_Sharing_Reason__c 
                                                        FROM ApexShare_Config__c 
                                                        WHERE Object_API_Name__c = :objName AND RecordTypeId = :RTId AND Active__c = TRUE]);

        //match SObject record id with respective ApexShare_Config records
        Set<String> sharingReasons = new Set<String>();
        Map<Id, List<ApexShare_Config__c>> recordIdShareConfigs = new Map<Id, List<ApexShare_Config__c>>();
        for(Id recordId: recordIds){
            List<ApexShare_Config__c> apexScList= new List<ApexShare_Config__c>();
            for(ApexShare_Config__c apexsc: idShareConfigs.values()){
                sharingReasons.add(apexsc.Apex_Sharing_Reason__c);
                apexScList.add(apexsc);
            }
            recordIdShareConfigs.put(recordId, apexScList);
        }

        //get all the criteria field api names to create a dynamic soql
        Set<String> allCriteria = new Set<String>();
        for(ApexShare_Config__c apexSC: idShareConfigs.values()){
            allCriteria.add(apexSC.Criteria_Field_Name__c);
        }

        String criteriaNames = NULL;
        for(String str: allCriteria){
            if(str != NULL){
                if(criteriaNames == NULL) criteriaNames = str;
                else criteriaNames = criteriaNames + ', ' + str;
            }
        }
        Map<Id, SObject> recordIdSobjects;
        if(criteriaNames != NULL){
            String queryString = 'SELECT Id, '+criteriaNames+' FROM '+objName+' WHERE Id IN :recordIds';
            System.debug('SOQL Query ' + queryString);
            recordIdSobjects = new Map<Id, SObject>(Database.query(queryString));
        }
        
        //delete existing share records for the same group
        String shareObjName = AutomatedSharingUtilities.findShareObject(objName);
        String deleteQueryString = 'SELECT Id, ParentId, UserOrGroupId, RowCause '+' FROM '+ shareObjName +
                                    ' WHERE ParentId IN :recordIds AND RowCause IN :sharingReasons';
        System.debug('Delete SOQL Query ' + deleteQueryString);
        List<SObject> oldShareRecords = new List<SObject>(Database.query(deleteQueryString));
        List<SObject> shareRecordsToDelete = new List<SObject>();
        for(SObject sObj: oldShareRecords){ 
            Id pId = (Id)sObj.get('ParentId');
            Id uId = (Id)sObj.get('UserOrGroupId');
            String reason = (String)sObj.get('RowCause');
            for(Id recordId: recordIds){
                for(ApexShare_Config__c apexSC: recordIdShareConfigs.get(pId)){
                    if(pId == recordId && reason == apexSC.Apex_Sharing_Reason__c ) shareRecordsToDelete.add(sObj);
                }
            }  
        }
        AutomatedSharingUtilities.deleteShareRecords(shareRecordsToDelete);

        //generate instances of share records for public group
        List<SObject> shareRecords = new List<SObject>();
        for(Id recordId: recordIdShareConfigs.keyset()){
            for(ApexShare_Config__c apexsc: recordIdShareConfigs.get(recordId)){
                String criteriaValue = NULL;
                if(apexSC.Criteria_Field_Name__c != NULL) criteriaValue = (String)recordIdSobjects.get(recordId).get(apexSC.Criteria_Field_Name__c);
                if(apexSC.Criteria_Field_Value__c == criteriaValue && criteriaValue != NULL){
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