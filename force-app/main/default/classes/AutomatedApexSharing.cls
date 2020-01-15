public class AutomatedApexSharing {
    public static SObject createShareObject(String objectName, Id recordId, Id userOrGroupId, String accessLevel){ 
        //construct name of the corresponding share object
        String shareObjectName;
        if(objectName.containsIgnoreCase('__C')){
            shareObjectName = objectName.removeEndIgnoreCase('__C') + '__share';
        }
        else shareObjectName = objectName + 'share';
        System.debug('The Share Object name is '+ shareObjectName);
        
        //create a new share object
        sObject sObj = Schema.getGlobalDescribe().get(shareObjectName).newSObject();
        
        // Set the ID of record being shared.
        sObj.put('ParentId', recordId);
        
        // Set the ID of user or group being granted access.
        sObj.put('UserOrGroupId', UserOrGroupId);
        
        // Set the access level.
        sObj.put('AccessLevel', AccessLevel);

        System.debug('The Share Object '+ shareObjectName + 
        ' is returned with ParentID = ' + sObj.get('ParentId') + ', UserGroupID = '+ 
        sObj.get('UserOrGroupId') + ' and AccessLevel = '+ sObj.get('AccessLevel'));

        return sObj;
    }

    public static void insertShareRecords(List<sObject> objectShares){
        // Insert the sharing record and capture the save result. 
        // The false parameter allows for partial processing if multiple records passed 
        // into the operation.
        Database.SaveResult[] lsr = Database.insert(objectShares,false);
        // if any errors, log errors
        for(Database.SaveResult sr: lsr){
            if(!sr.isSuccess()){
                Database.Error err = sr.getErrors()[0];
                System.debug('Error creating share record: ' + err.getMessage());
            }
        }
    }

    
    @InvocableMethod(label='Create Sharing Records' description='Creates sharing records based on the configs from ApexShare Config object')
    public static void createShareRecords(List<Id> recordIds){
        //identify object type
        Schema.SObjectType token = recordIds[0].getSobjectType();
        Schema.DescribeSObjectResult objResult = token.getDescribe();
        String objName = objResult.getName();

        //get the object config details
        Map<Id, ApexShare_Config__c> idShareConfigs = new MAP<Id, ApexShare_Config__c>([SELECT Id, 
                                                        Object_API_Name__c, 
                                                        Access__c,
                                                        RecordTypeId, 
                                                        Lookup_API_Name__c,
                                                        Group_Role_ID__c 
                                                        FROM ApexShare_Config__c 
                                                        WHERE Object_API_Name__c = :objName]);

        //match record id with respective share configs
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
        System.debug('The concatenated api names are ' + lookupApiName);
        System.debug('The object api name is ' + objName);
        for(String str: lookups){
            System.debug('The lookup api name: ' + str);
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
                    RSWU.AccessLevel = apexSC.Access__c;
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
                Sobject sObj = createShareObject(
                    rswu.ObjectAPIName, 
                    recordId,
                    rswu.lookupUserId,
                    rswu.accessLevel
                    );
            shareRecords.add(sObj);
            }
        }

        //generate instances of share records for public group
        for(Id recordId: recordIdShareConfigs.keyset()){
            for(ApexShare_Config__c apexsc: recordIdShareConfigs.get(recordId)){
                if(apexsc.RecordTypeId == Schema.SObjectType.ApexShare_Config__c.getRecordTypeInfosByName().get('Share with Public Group').getRecordTypeId()){
                    Sobject sObj = createShareObject(
                    apexsc.Object_API_Name__c, 
                    recordId,
                    apexsc.Group_Role_ID__c, 
                    apexsc.Access__c
                    );
                shareRecords.add(sObj);
                }
            }
        }

        //Create share records
        insertShareRecords(shareRecords);
    }

    //apex data object to store recordId, LookupAPI, and the corresponding UserId
    public class RecordShareWithUser{
        Id recordId = NULL;
        String ObjectAPIName = NULL;
        Id apexSCId = NULL;
        String accessLevel = NULL;
        String lookupAPIname;
        Id lookupUserId = NULL;
    }
}