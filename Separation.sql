USE [DATABASE]
GO
/******  ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[IdentificationProc] 
AS
BEGIN
TRUNCATE TABLE DISCREPANCY
TRUNCATE TABLE ClientList
 
declare @ClientList table (

		 RegNum varchar(9)
		,ClientName nvarchar(50)
		,ClientSurname nvarchar(50)
		,BirthDate date
		,ClInfo_clientcode varchar(5)
		,Acc_AccountID varchar(20)
		,Acc_OpenDate datetime
		,ClInfo_ClientCode NVARCHAR(MAX)
		,Acc_Status nvarchar(3) 
		,Acc_CloseDate datetime
		)

	insert	INTO @ClientList 
		select ClInfo_regnum ,
		ClInfo_name ,
		ClInfo_surname ,
		ClInfo_BirthDate ,
		ClInfo_ClientCode ,
		Acc_ClientCode ,
		Acc_opendate ,
		ClInfo_ClientCode,
		Acc_status ,
		Acc_closeDate  

FROM ClientInfo
JOIN Account
ON ClientInfo.ClInfo_ClientCode=Account.Acc_ClientCode
WHERE ClInfo_regnum<>'' and left(Acc_ClientCode,1) = '3'
AND LEN(ClInfo_regnum) = 9
and ClInfo_ClientCode >= 11000


insert	INTO ClientList 
		select ClInfo_regnum ,
		ClInfo_name ,
		ClInfo_surname ,
		ClInfo_BirthDate ,
		ClInfo_ClientCode ,
		Acc_ClientCode ,
		Acc_opendate ,
		ClInfo_ClientCode,
		Acc_status ,
		Acc_closeDate  

FROM ClientInfo
JOIN Account
ON ClientInfo.ClInfo_ClientCode=Account.Acc_ClientCode
WHERE ClInfo_regnum<>'' and left(Acc_ClientCode,1) = '3'
AND LEN(ClInfo_regnum) = 9
and ClInfo_ClientCode >= 11000


/*Retrieve Information from the Header of the Request*/

DECLARE @RequestType	CHAR(1)			
DECLARE @DateOfRequest	CHAR(6) 
DECLARE @Request_Issue_Date CHAR (8) 
DECLARE @NrOfTaxPayers	CHAR (7)
DECLARE @Request_Header VARCHAR(MAX) = (SELECT TOP 1 ROWTEXT FROM Request_Table)

SET @RequestType = SUBSTRING ( @Request_Header,1,1)
SET @DateOfRequest = SUBSTRING (@Request_Header,2,6)
SET @Request_Issue_Date = SUBSTRING (@Request_Header,8,8)
SET @NrOfTaxPayers = SUBSTRING (@Request_Header,16,7)



/*Retrieve Data from each record and create the reply's header*/
DECLARE @Gov_RegNum nvarCHAR(9)				
DECLARE @Gov_name nvarCHAR(3)
DECLARE @Gov_Surname nvarCHAR (3)
DECLARE @Gov_BirthDate nvarCHAR(8) 
DECLARE @Record_Request_Date nvarCHAR(8)
DECLARE @Loan_possession nvarCHAR(1)
DECLARE @Record nVARCHAR(32) 
declare @LocalID int

DECLARE @REPLY_HEADER NVARCHAR (117) = 'F' + '123456789' + DBO.PAD(100,'Payment Institution','r',' ') + @NrOfTaxPayers
INSERT INTO Reply_Table VALUES (@REPLY_HEADER,'')

/*Start of Cursor*/
DECLARE CONTROLLER CURSOR FOR 
SELECT	 id, rowtext  FROM Request_Table where len(rowtext) > 22

OPEN CONTROLLER
FETCH NEXT FROM CONTROLLER into @LocalID, @Record


WHILE @@FETCH_STATUS = 0
BEGIN

	SET @Gov_RegNum = SUBSTRING(@Record,1,9)
	SET @Gov_name = SUBSTRING (@Record,10,3)
	SET @Gov_Surname = SUBSTRING(@Record,13,3)
	SET @Gov_BirthDate = SUBSTRING (@Record,16,8)
	SET @Record_Request_Date = SUBSTRING (@Record,24,8)
	SET @Loan_possession = SUBSTRING(@Record,32,1)
	
	
	

	/*1rst scenario in which Reg Num does not match*/
	IF NOT EXISTS (SELECT 1 FROM @ClientList WHERE @Gov_RegNum=RegNum)   
		BEGIN
			GOTO Finish
		END


	

	/*2nd scenario, where there is a match of the Names and the Birthdays*/
	DECLARE @ClInfo_name nVARCHAR(5)
	DECLARE @ClInfo_Surname nVARCHAR(5)
	DECLARE @PELACOD nVARCHAR(5)
	DECLARE @Acc_AccountID NVARCHAR(15)
	DECLARE @BirthDate NVARCHAR (8)
	DECLARE @Acc_Status NVARCHAR(5)
	DECLARE @Acc_CloseDate VARCHAR(30)
	DECLARE @Gov_Final_BirthDate VARCHAR  (MAX)= SUBSTRING (@Gov_BirthDate,1,4) +  SUBSTRING (@Gov_BirthDate,5,2) + SUBSTRING (@Gov_BirthDate,7,2)
	DECLARE @BALANCE MONEY
	DECLARE @Acc_opendate VARCHAR (MAX) = (SELECT CONVERT (VARCHAR (8) ,Acc_OpenDate,112) FROM @ClientList WHERE ClInfo_clientcode=@pelacod)

		select	@ClInfo_name = ClientName,    
				@ClInfo_Surname = ClientSurname, 
				@pelacod = ClInfo_clientcode, 
				@Acc_AccountID = Acc_AccountID, 
				@BirthDate = convert (varchar(8),BirthDate,112),
				@Acc_Status = Acc_Status,
				@Acc_CloseDate = (SELECT CONVERT (VARCHAR(8),Acc_CloseDate ,112))
				FROM @ClientList WHERE @Gov_RegNum=RegNum


		IF @Gov_Final_BirthDate<>@BirthDate 
			BEGIN
			INSERT INTO DISCREPANCY 
				SELECT	
						
						@ClInfo_name,
						@ClInfo_Surname,
						@Gov_name,
						@Gov_Surname,
						@Gov_RegNum,
						@BirthDate,
						@Gov_BirthDate,
						@Record_Request_Date,
						@Loan_possession,
						'Mismatch of Birthdate',
						@LocalID

			GOTO Finish
			END

		IF (@Gov_name=LEFT (@ClInfo_name,3) and @Gov_Surname=LEFT(@ClInfo_Surname,3) ) 
			BEGIN
				EXEC DBO.Reply_Writer @Directive='WRITE',@RegNum=@Gov_RegNum,@Record_Request_Date=@Record_Request_Date, @Loan_Possession = @Loan_possession,  @LocalID=@LocalID
				GOTO Finish
			END 
			
			

			
		/*3rd scenario, where there is a match of the English version of the name and the birtday*/
		DECLARE @Gov_latin_name nVARCHAR (5) = DBO.GREEK_TO_LATIN(@Gov_name)
		DECLARE @ClInfo_latin_name nVARCHAR  (5)= DBO.GREEK_TO_LATIN(@ClInfo_name)
		DECLARE @Gov_Latin_Surname nVARCHAR  (5)= DBO.GREEK_TO_LATIN(@Gov_Surname)
		DECLARE @ClInfo_Latin_Surname nVARCHAR  (5)= DBO.GREEK_TO_LATIN(@ClInfo_Surname)
		DECLARE @ClInfo_latin_name_pref nVARCHAR (5) = LEFT (@ClInfo_latin_name,3)
		DECLARE @ClInfo_Latin_Surname_pref nVARCHAR  (5)= LEFT (@ClInfo_Latin_Surname,3) 
			
		DECLARE @Gov_name_len INT, 
				@Gov_Surname_Len int, 
				@ClInfo_name_len int, 
				@ClInfo_Sunrame_Len int
			
		set @Gov_Surname_Len = len(trim(@Gov_Latin_Surname))
		set @ClInfo_Sunrame_Len = len(trim(@ClInfo_Latin_Surname_pref))
		SET @Gov_name_len = len(trim(@Gov_latin_name))
		SET @ClInfo_name_len = len(trim(@ClInfo_latin_name_pref))

		IF @ClInfo_Sunrame_Len =  @ClInfo_Sunrame_Len  and  @Gov_name_len = @ClInfo_name_len and( (@Gov_Latin_Surname = @ClInfo_Latin_Surname_pref and @Gov_latin_name = @ClInfo_latin_name_pref ) or (@Gov_Latin_Surname =@ClInfo_latin_name_pref and @Gov_latin_name = @ClInfo_Latin_Surname_pref))
			BEGIN
				EXEC DBO.Reply_Writer @Directive='WRITE',@RegNum=@Gov_RegNum,@Record_Request_Date=@Record_Request_Date,  @Loan_Possession = @Loan_possession,  @LocalID=@LocalID
				GOTO Finish
			END
		


		/*4th and last case in which we alter the legth of the prefix to try and match the English prefixes*/
		DECLARE @ClInfo_Surname_pref NVARCHAR(5) = LEFT(@ClInfo_Surname, @Gov_Surname_Len)
		DECLARE @NAME_PREF NVARCHAR(5) = LEFT(@ClInfo_name,@Gov_name_len) 

		IF (@Gov_latin_name=@NAME_PREF AND @Gov_Latin_Surname=@ClInfo_Surname_pref AND @Gov_Final_BirthDate=@BirthDate)
			OR (@Gov_latin_name=@ClInfo_Surname_pref AND @Gov_Latin_Surname=@NAME_PREF AND @Gov_Final_BirthDate=@BirthDate) 
				BEGIN
					EXEC DBO.Reply_Writer @Directive='WRITE',@RegNum=@Gov_RegNum,@Record_Request_Date=@Record_Request_Date,  @Loan_Possession = @Loan_possession,  @LocalID=@LocalID
					GOTO Finish
				END 
					
		INSERT INTO DISCREPANCY
		SELECT			@ClInfo_name,
						@ClInfo_Surname,
						@Gov_name,
						@Gov_Surname,
						@Gov_RegNum,
						@BirthDate,
						@Gov_BirthDate,
						@Record_Request_Date,
						@Loan_possession,
				'No match of RegNum, Name or Birthday',
				@LocalID


	
Finish:
FETCH NEXT FROM CONTROLLER into @LocalID, @Record
END

CLOSE CONTROLLER
DEALLOCATE CONTROLLER

END
------



