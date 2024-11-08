USE [DATABASE]
GO
/******  ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Reply_Writer]
(	
	@Directive NVARCHAR(5),
	@RegNum NVARCHAR(9),
	@Record_Request_Date NVARCHAR(8),
	@Loan_Possession varchar(1) 
	,@LocalID int = null
	
)
AS
BEGIN


	IF (@Directive='WRITE')
	begin
		update Request_Table set result = 1 where id = @LocalID
		dECLARE @RESULT VARCHAR(MAX)
		DECLARE @@ClientCodeTrim INT
		DECLARE @ClientCode NVARCHAR (10)= (SELECT ClInfo_ClientCode FROM ClientList WHERE RegNum=@RegNum)
		set @@ClientCodeTrim = cast(trim(@ClientCode) as int)
		DECLARE @BALANCE MONEY
		DECLARE @Account NVARCHAR(15) = (SELECT Account FROM ClientList WHERE RegNum=@RegNum)
		DECLARE @Acc_Status NVARCHAR(5) = (SELECT Acc_Status FROM ClientList WHERE RegNum=@RegNum) 
		DECLARE @Acc_OpenDate NVARCHAR(8)= (SELECT CONVERT (VARCHAR (8) ,Acc_OpenDate,112) FROM ClientList WHERE RegNum=@RegNum)
		DECLARE @Acc_CloseDate NVARCHAR(8)= (SELECT CONVERT (VARCHAR (8) ,Acc_CloseDate,112) FROM ClientList WHERE RegNum=@RegNum)
		declare @Unique_code varchar(4)




		IF @Acc_Status = 'ΕΑ'
			begin 
		
			 if @Acc_OpenDate<=@Record_Request_Date
				BEGIN
					SET @RESULT = ( 'O' + @RegNum + @Record_Request_Date + @Loan_Possession + '001')
					INSERT INTO Reply_Table  (rowtext,RegNum) VALUES(@RESULT,@RegNum)
					set @balance = ( SELECT SUM(isnull(trans_deposit,0)-isnull(trans_withdraw,0)) AS Client_Balance FROM Transactions 
								WHERE trans_date <= @Record_Request_Date + ' 23:59:59'
								and @ClientCode = trans_clientcode) 

					DECLARE @SYMBOL NVARCHAR(1)
					SET @SYMBOL = CASE WHEN ( SELECT SUM(isnull(trans_deposit,0)-isnull(trans_withdraw,0)) AS Client_Balance FROM Transactions 
									WHERE trans_date <= @Record_Request_Date + ' 23:59:59'
									and @ClientCode = trans_clientcode) >= 0
									THEN 'C'
									ELSE 'D'
									END

					set @unique_code =  right(CONVERT(NVARCHAR(12), CONVERT(VARBINARY(8), @@ClientCodeTrim), 1),4)
					SET @BALANCE = ABS(@BALANCE)
					SET @RESULT = ('D' + '67' +'001' + dbo.pad(75, 'Payment Account ' + right(@Account,9) ,'R',' ') + @Unique_code + dbo.pad(13,cast(isnull(@BALANCE,0) as nvarchar(13)),'L',' ') + @SYMBOL + 'EUR')
			
					INSERT INTO Reply_Table (rowtext,RegNum) VALUES(@RESULT,@RegNum)
				END
			else
				BEGIN
					SET @RESULT = ( 'O' + @RegNum + @Record_Request_Date + @Loan_Possession + '000')
					INSERT INTO Reply_Table  (rowtext,RegNum) VALUES(@RESULT,@RegNum)
				END

		end
		
		IF @Acc_Status = 'ΟΕ'
			begin 
				

				if  @Acc_OpenDate<=@Record_Request_Date AND @Acc_CloseDate>=@Record_Request_Date
					begin
					
						SET @RESULT = ( 'O' + @RegNum + @Record_Request_Date + @Loan_Possession + '001')
						INSERT INTO Reply_Table (rowtext,RegNum)  VALUES(@RESULT,@RegNum)
						set @balance = ( SELECT SUM(isnull(trans_deposit,0)-isnull(trans_withdraw,0)) AS Client_Balance FROM Transactions 
									WHERE trans_date <= @Record_Request_Date + ' 23:59:59'
									and @ClientCode = trans_clientcode) 

					DECLARE @SYMBOL2 NVARCHAR(1)
					SET @SYMBOL2 = CASE WHEN ( SELECT SUM(isnull(trans_deposit,0)-isnull(trans_withdraw,0)) AS Client_Balance FROM Transactions 
									WHERE trans_date <= @Record_Request_Date + ' 23:59:59'
									and @ClientCode = trans_clientcode) >= 0
									THEN 'C'
									ELSE 'D'
									END

					SET @BALANCE = ABS(@BALANCE)
						set @unique_code =  right(CONVERT(NVARCHAR(12), CONVERT(VARBINARY(8), @@ClientCodeTrim), 1),4)
						SET @RESULT = ('D' + '67' +'001' + dbo.pad(75, 'Payments Account ' + right(@Account,9) ,'R',' ') + @Unique_code + dbo.pad(13,cast(isnull(@BALANCE,0) as nvarchar(13)),'L',' ') + @SYMBOL2 + 'EUR')
						INSERT INTO Reply_Table (rowtext,RegNum)  VALUES(@RESULT,@RegNum)
					end
				else
				begin
					
					SET @RESULT = ( 'O' + @RegNum + @Record_Request_Date + @Loan_Possession + '000')
					INSERT INTO Reply_Table (rowtext,RegNum)  VALUES(@RESULT,@RegNum)
				end
			end
	end


	IF (@Directive='DIE')
		BEGIN
			SET @RESULT = ( 'O' + @RegNum + @Record_Request_Date + @Loan_Possession + '-1')
			INSERT INTO Reply_Table  (rowtext,RegNum) VALUES(@RESULT,'')
		END



END
