public class AutomatedSharingUtilities {
    
    public static SObject createShareObject(String objectName, Id recordId, Id userOrGroupId, String accessLevel, String sharingReason){ 
        //construct name of the corresponding share object
        String shareObjectName = findShareObject(objectName);

        //create a new share object
        sObject sObj = Schema.getGlobalDescribe().get(shareObjectName).newSObject();
        
        // Set the ID of record being shared.
        sObj.put('ParentId', recordId);
        
        // Set the ID of user or group being granted access.
        sObj.put('UserOrGroupId', UserOrGroupId);
        
        // Set the access level.
        sObj.put('AccessLevel', AccessLevel);

        // Set the rowcause.
        sObj.put('RowCause', sharingReason);

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

    public static void deleteShareRecords(List<sObject> objectShares){
        // Delete the sobject records
        Database.DeleteResult[] drList = Database.delete(objectShares, false);

        // Iterate through each returned result
        for(Database.DeleteResult dr : drList) {
            if (dr.isSuccess()) {
                // Operation was successful, so get the ID of the record that was processed
                System.debug('Successfully deleted share record with ID: ' + dr.getId());
            }
            else {
                // Operation failed, so get all errors                
                for(Database.Error err : dr.getErrors()) {
                    System.debug('The following error has occurred.');                    
                    System.debug(err.getStatusCode() + ': ' + err.getMessage());
                    System.debug('Fields that affected this error: ' + err.getFields());
                }
            }
        }
    }

    public static String findShareObject(String objectName){
        //construct name of the corresponding share object
        String shareObjectName;
        if(objectName.containsIgnoreCase('__C')){
            shareObjectName = objectName.removeEndIgnoreCase('__C') + '__share';
        }
        else shareObjectName = objectName + 'share';
        System.debug('The Share Object name is '+ shareObjectName);

        return shareObjectName;
    }

}