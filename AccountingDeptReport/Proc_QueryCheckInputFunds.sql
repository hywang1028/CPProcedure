if OBJECT_ID(N'Proc_QueryCheckInputFunds',N'p') is not null
begin
	drop procedure Proc_QueryCheckInputFunds;	
end
go
 
create procedure Proc_QueryCheckInputFunds  
 @StartDate datetime = '2012-01-01',  
 @EndDate datetime = '2012-09-20'  
as  
begin  
  
  
--1. Check input  
if (@StartDate is null or  @EndDate is null)  
begin  
 raiserror(N'Input params cannot be empty in Proc_QueryCheckInputFunds', 16, 1)  
end  
  
  
--2. Prepare StartDate and EndDate  
declare @CurrEndDate datetime;  
set @CurrEndDate = DATEADD(DAY,1,@EndDate);  
  
  
--3.Prepare All Data  
select  
 GateNo,  
 SUM(TransCnt) TransCnt,  
 SUM(TransAmt)/100.0 TransAmt  
from  
 Table_ReconFileInfo  
where  
 UploadDate >= @StartDate  
 and  
 UploadDate < @CurrEndDate  
group by  
 GateNo;  
  
  
end  
  
  
  
  
  
  
  
  