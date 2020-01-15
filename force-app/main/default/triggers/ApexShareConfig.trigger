trigger ApexShareConfig on ApexShare_Config__c (before insert, before update) {
    //get all record types for this object
    Map<ID,Schema.RecordTypeInfo> rt_Map = ApexShare_Config__c.sObjectType.getDescribe().getRecordTypeInfosById();
    
    //get all the groups mentioned in ApexShare Configs
    List<String> groupNames = new List<String>();    
    for(ApexShare_Config__c apexSC: Trigger.new){
        if(rt_map.get(apexSC.recordTypeID).getName().containsIgnoreCase('Share with Public Group')) groupNames.add(apexSC.Group_Role_Name__c);
    }
    List<Group> targetGroups = new List<Group>([Select Id, DeveloperName, Type FROM Group WHERE DeveloperName IN :groupNames AND Type = 'Regular']);
    Map<String, Group> targetGroupMap = new Map<String, Group>();
    for(Group grp: targetGroups){
        if(grp.Type == 'Regular') targetGroupMap.put(grp.DeveloperName, grp);
    }

    //validate object name, lookup api name, group developer name, and duplicate share configs
    for(ApexShare_Config__c apexSC: Trigger.new){
        //check for object api name
        SObjectType objToken = Schema.getGlobalDescribe().get(apexSC.Object_API_Name__c);
        if(objToken == NULL){
            apexSC.addError('Could not find the object '+ apexSC.Object_API_Name__c + '; Please check the Object API Name.');
            continue;
        }
        
        // check the lookup api name for the same object
        if(rt_map.get(apexSC.recordTypeID).getName().containsIgnoreCase('Share with User')){
            System.debug('The current record type is Share with User');
            DescribeSObjectResult objDef = objToken.getDescribe();
            Map<String, SObjectField> fields = objDef.fields.getMap();
            SObjectField fieldToken = fields.get(apexSC.Lookup_API_Name__c);
            if(fieldToken == NULL){
                apexSC.addError('Could not find the field '+ apexSC.Lookup_API_Name__c + ' in the object '+ apexSC.Object_API_Name__c + '; Please check the User Lookup API Name.');
            }
            apexSC.Object_Lookup_Combination__c = apexSC.Object_API_Name__c + apexSC.Lookup_API_Name__c;
        }
        
        // check the existence public group by its developer name
        else if(rt_map.get(apexSC.recordTypeID).getName().containsIgnoreCase('Share with Public Group')){
            System.debug('The current record type is Share with Public Group');
            if(targetGroupMap.containsKey(apexSC.Group_Role_Name__c)){
                apexSC.Group_Role_Id__c = targetGroupMap.get(apexSC.Group_Role_Name__c).Id;
            }
            else apexSC.addError('Could not find the public group '+ apexSC.Group_Role_Name__c + '; Please check the public group developer name.');
            apexSC.Object_Group_Combination__c = apexSC.Object_API_Name__c + apexSC.Group_Role_Name__c;
        }
        
    }

}