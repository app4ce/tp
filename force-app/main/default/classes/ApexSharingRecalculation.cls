global class ApexSharingRecalculation implements Database.Batchable<sObject>, Database.Stateful {
    
    // String to hold email address that emails will be sent to. 
    // Replace its value with a valid email address.
    static String emailAddress = UserInfo.getUserEmail();

    //get all record types for this object
    transient Map<ID,Schema.RecordTypeInfo> rt_Map = ApexShare_Config__c.sObjectType.getDescribe().getRecordTypeInfosById();
    
    //pass parameters
    private ApexShare_Config__c apexSC;
    private String objName;
    private String lookupName;
    private String criteriaFieldName;
    private String criteriaFieldValue;
    private Id groupId;
    private String sharingReason;
    private String accessLevel;
    private Boolean active;
    private Boolean sendEmail;
    private String recordTypeName;

    public ApexSharingRecalculation(Id apexSCId, Boolean sendEmail) {
        ApexShare_Config__c apexSC = [SELECT Id, 
                                        Object_API_Name__c, 
                                        Lookup_API_Name__c,
                                        Criteria_Field_Name__c,
                                        Criteria_Field_Value__c,
                                        Group_Role_ID__c,
                                        Apex_Sharing_Reason__c,
                                        Access__c,
                                        Active__c, 
                                        RecordTypeId
                                        FROM ApexShare_Config__c 
                                        WHERE Id = :apexSCId
                                        LIMIT 1];
        this.apexSC = apexSC;
        this.objName = apexSC.Object_API_Name__c;
        this.lookupName = apexSC.Lookup_API_Name__c;
        this.criteriaFieldName = apexSC.Criteria_Field_Name__c;
        this.criteriaFieldValue = apexSC.Criteria_Field_Value__c;
        this.groupId = apexSC.Group_Role_ID__c;
        this.sharingReason = apexSC.Apex_Sharing_Reason__c;
        this.accessLevel = apexSC.Access__c;
        this.active = apexSC.Active__c;
        this.sendEmail = sendEmail;
        this.recordTypeName = rt_map.get(apexSC.RecordTypeID).getName();
    }
    
    // The start method is called at the beginning of a sharing recalculation.
    // This method returns a SOQL query locator containing the records 
    // to be recalculated. 
    global Database.QueryLocator start(Database.BatchableContext BC){
        String queryString;
        if(criteriaFieldName != NULL){
            if(recordTypeName.containsIgnoreCase('Share with Public Group')){
                queryString = 'SELECT Id, '+ 
                            criteriaFieldName +
                            ' FROM '+ objName;
            }
            else if(recordTypeName.containsIgnoreCase('Share with User')){
                queryString = 'SELECT Id, '+ lookupName +', '+ 
                            criteriaFieldName +
                            ' FROM '+ objName + 
                            ' WHERE '+ lookupName +' != NULL';
            }
        }
        else {
            if(recordTypeName.containsIgnoreCase('Share with Public Group')){
                queryString = 'SELECT Id '+ 
                            ' FROM '+ objName;
            }
            else if(recordTypeName.containsIgnoreCase('Share with User')){
                queryString = 'SELECT Id, '+ lookupName + 
                            ' FROM '+ objName + 
                            ' WHERE '+ lookupName +' != NULL';
            }
        }
        System.debug('QueryLocator string: '+ queryString);
        return Database.getQueryLocator(queryString);  
    }
    
    // The executeBatch method is called for each chunk of records returned from start.  
    global void execute(Database.BatchableContext BC, List<sObject> scope){
        // Create a map for the chunk of records passed into method.
        Map<ID, SObject> sObjMap = new Map<ID, SObject>(scope);  
        
        // Create a list of share objects to be inserted.
        List<SObject> newShareRecords = new List<SObject>();
        
        // Construct share records for every custom object records in the batch
        for(SObject sObj : sObjMap.values()){
            if(criteriaFieldName != NULL){
                // use criteria field name/value to determine the need for sharing record
                if(sObj.get(criteriaFieldName) == criteriaFieldValue && active == TRUE && recordTypeName.containsIgnoreCase('Share with User')){
                    Sobject sObjShare = AutomatedSharingUtilities.createShareObject(
                        objName, 
                        sObj.Id,
                        (Id)sObj.get(lookupName), //group id if it is group recalculation
                        accessLevel,
                        sharingReason
                        );
                newShareRecords.add(sObjShare);
                }
                else if(sObj.get(criteriaFieldName) == criteriaFieldValue && active == TRUE && recordTypeName.containsIgnoreCase('Share with Public Group')){
                    Sobject sObjShare = AutomatedSharingUtilities.createShareObject(
                        objName, 
                        sObj.Id,
                        groupId, //group id if it is group recalculation
                        accessLevel,
                        sharingReason
                        );
                newShareRecords.add(sObjShare);
                }
            }
            else {
                // use criteria field name/value to determine the need for sharing record
                if(active == TRUE && recordTypeName.containsIgnoreCase('Share with User')){
                    Sobject sObjShare = AutomatedSharingUtilities.createShareObject(
                        objName, 
                        sObj.Id,
                        (Id)sObj.get(lookupName), //group id if it is group recalculation
                        accessLevel,
                        sharingReason
                        );
                newShareRecords.add(sObjShare);
                }
                else if(active == TRUE && recordTypeName.containsIgnoreCase('Share with Public Group')){
                    Sobject sObjShare = AutomatedSharingUtilities.createShareObject(
                        objName, 
                        sObj.Id,
                        groupId, //group id if it is group recalculation
                        accessLevel,
                        sharingReason
                        );
                newShareRecords.add(sObjShare);
                }
            }  
        }
               
        // delete existing share records for the retrieved custom object records
        if(active == TRUE){
            List<Id> recordIds = new List<Id>(sObjMap.keySet());
            Set<String> sharingReasons = new Set<String>();
            sharingReasons.add(sharingReason);
            AutomatedSharingUtilities.deleteShareRecords(recordIds, sharingReasons);
        }
        
        try {
           // Insert the new sharing records and capture the save result. 
           // The false parameter allows for partial processing if multiple records are 
           // passed into operation. 
           Database.SaveResult[] lsr = Database.insert(newSharerecords,false);
           
           // Process the save results for insert.
           for(Database.SaveResult sr : lsr){
               if(!sr.isSuccess()){
                   // Get the first save result error.
                   Database.Error err = sr.getErrors()[0];
                   
                   // Check if the error is related to trivial access level.
                   // Access levels equal or more permissive than the object's default 
                   // access level are not allowed. 
                   // These sharing records are not required and thus an insert exception 
                   // is acceptable. 
                   if(!(err.getStatusCode() == StatusCode.FIELD_FILTER_VALIDATION_EXCEPTION  
                                     &&  err.getMessage().contains('AccessLevel'))){
                       // Error is not related to trivial access level.
                       // Send an email to the Apex job's submitter.
                     Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                     String[] toAddresses = new String[] {emailAddress}; 
                     mail.setToAddresses(toAddresses); 
                     mail.setSubject('Apex Sharing Recalculation Exception');
                     mail.setPlainTextBody(
                       'The Apex sharing recalculation threw the following exception: ' + 
                             err.getMessage());
                     Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                   }
               }
           }   
        } catch(DmlException e) {
           // Send an email to the Apex job's submitter on failure.
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[] {emailAddress}; 
            mail.setToAddresses(toAddresses); 
            mail.setSubject('Apex Sharing Recalculation Exception');
            mail.setPlainTextBody(
              'The Apex sharing recalculation threw the following exception: ' + 
                        e.getMessage());
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }
    
    // The finish method is called at the end of a sharing recalculation.
    global void finish(Database.BatchableContext BC){  
        // Send an email to the Apex job's submitter notifying of job completion.
        if(sendEmail){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[] {emailAddress}; 
            mail.setToAddresses(toAddresses); 
            mail.setSubject('Apex Sharing Recalculation Completed.');
            mail.setPlainTextBody
                      ('The Apex sharing recalculation finished processing');
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }
    
}