public void getLicenses(){

	String finalResults;

	//grabs licenses that match Salesforce*, so Salesforce and Salesforce Platform 
	Map<ID, UserLicense> licenseMap = new Map<ID, UserLicense>( 
											[select Id,Name 
											from UserLicense 
											where Name LIKE 'Salesforce%'] );//salesforce or salesforce platform

	//grabs all user profiles that have the prior two types of licenses
	Map<ID, Profile> profileMap = new Map<ID, Profile>( [select Id,Name,UserLicenseId from Profile where UserLicenseId in :licenseMap.keySet()] );

	//grabs a list of users that are active and have one of the previously queried profiles -- Manager, Finance User, Development etc. 
	// PowerCustomerSuccess is the portal user, I got that name from checking the User table from SoQl.. i don't think it's actually needed
	List<User> userList = new List<User> ([select UserName,
									Name,
									UserType,
									Email,
									UserRoleId,
									ProfileId,
									IsActive,
									Contact_Id_PR__c,
									PortalRole
									from User where (IsActive = True AND UserType <> 'PowerCustomerSuccess') AND ProfileId = :profileMap.keySet()]);

	//i make a separate list for the contactId's of the user profiles just because i didn't feel like re-writing everything by making 'userlist' a Map object
	//grabs all of the Contact_Id_PR__c's from the user's list
	List<String> contactIds = new List<String>();
	for ( User s : userList ){
		contactIds.add(s.Contact_Id_PR__c);
	}
	//building maps for the contacts and entities
	Map<Id, Contact> contactMap = new Map<Id, Contact>([select Name,Entity__c from Contact where Id = :contactIds ]);

	//small number of entities, but large amount of profiles/user
	Set<String> entityIdSet = new Set<String>();
	for ( String c : contactMap.keySet() ){
		entityIdSet.add(contactMap.get(c).Entity__C); //getting the Entity__c Ids from the 
	}//contactMap.get(c) returns a Contact with Id = c. The .Entity__C grabs the String representing the Id of the Entity. Then the Id is added to the Set

	Map<Id, Entity__c> entityMap = new Map<Id, Entity__c>([select Name from Entity__c where Id = :entityIdSet]);

	// so, some profiles do not have an entity assigned to them. so the results return null. but if you try to pass null to something
	// you get an exception. So I need to check for Null in entities before I can output a final result
	Integer sfCount = 0;
	Integer sfpCount = 0;
	Entity__c placeHolder = new Entity__c(Id = 'a1iF0000000Ngj3IAC', Name = 'SA-NOPE'); //fake entity
	Entity__c finalEntity;

	//runs through the user list looking for the profile type, then license type, then checks to see if entity is Null before outputting the results
	System.debug('Length of loop: ' + userList.size() );
	for ( User u : userList ) {
		Profile profName = profileMap.get(u.ProfileId);
		UserLicense licName = licenseMap.get(profName.UserLicenseId);

		Integer y = licName.Name.equals('Salesforce') ? sfCount++ : sfpCount++;

			try {
				finalEntity = entityMap.get(contactMap.get(u.Contact_Id_PR__c).Entity__c);
			}
			catch(Exception ex){
				System.debug('Encountered Null Entity for ' + u.Name);
				finalEntity = new Entity__c(Id = placeHolder.Id, Name = placeHolder.Name ); 
			}

		System.debug('\nUser: ' + u.Name + '\nis a : ' + profName.Name + 
						'\n with license: ' + licName.Name + 
						'\n in Entity ' +  finalEntity.Name );
		System.debug('\nSalesforce Count: ' + sfCount + '\nSalesforce Platform Count: ' + sfpCount);
		finalResults += (u.Name + ' , ' + profName.Name + ' , ' + 
						licName.Name + ' , ' + u.Email + ' , ' + 
						finalEntity.Name + '\n');

	}
	System.debug('Total number of Salesforce Licenses: ' + sfCount);
	System.debug('Total number of Platform Licenses: ' + sfpCount);

	finalResults = 'Full Name' + ' , ' + 'Profile Name' + ' , ' + ' License Type ' + ' , ' + 'Email Address' + ' , ' + 'Entity' + '\n' + finalResults;
	//emailResults(finalResults);

}

public void emailResults( String results ){

	//Create a new File Attachment, Message (email) object, attach the distinct
	//list of Record Type names and send via email
	Messaging.EmailFileAttachment csvAttc = new Messaging.EmailFileAttachment();
	blob csvBlob = Blob.valueOf(results);

	Datetime myDatetime = Datetime.now();
	String myDatetimeStr = myDatetime.format('MMMM d yyyy');

	string csvname= 'salesforceResults_' + myDatetimeStr + '.csv';


	csvAttc.setFileName(csvname);
	csvAttc.setBody(csvBlob);
	
	Messaging.SingleEmailMessage email =new Messaging.SingleEmailMessage();
	List<String> toAddresses = new List<String>{'louis.tur@successacademies.org','Sara.Sherrod@successacademies.org','Rebecca.Fader@successacademies.org',
												'Andrew.Mendoza@successacademies.org','Jessica.Wagner@successacademies.org', 'Adam.Rosso@successacademies.org'};
	String subject ='Re: # of Platform Licenses';
	
	email.setSubject(subject);
	email.setToAddresses( toAddresses );
	email.setPlainTextBody('This is a 99.9% accurate list of who has what license. We can also use this script to look for those\n profiles need email/entity updates (if we want to even bother).\n\n But the good news is, that the # of licenses in use accourding to this script matches exactly what it is listing\n in Salesforce under our company profile');
	email.setFileAttachments(new Messaging.EmailFileAttachment[]{csvAttc});
	
	Messaging.SendEmailResult [] r = Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});

}

getLicenses();