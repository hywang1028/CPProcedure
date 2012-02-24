if OBJECT_ID(N'Proc_QueryOraBankCostCalc', N'P') is not null
begin
	drop procedure Proc_QueryOraBankCostCalc;
end
go 

create procedure Proc_QueryOraBankCostCalc  
 @StartDate datetime = '2011-06-01',  
 @EndDate datetime = '2011-08-01'  
as  
begin  
  
declare @MaxDate datetime;
set @MaxDate = '2200-01-01';
  
--1. CheckInput  
if(@StartDate is null or @EndDate is null)  
begin  
 raiserror(N'Input params can`t be empty in Proc_QueryOraBankCostCalc',16,1);  
end  
  
  
--2 Get Daily Trans  
select  
	BankSettingID,
	MerchantNo,  
	CPDate,  
	TransCount,  
	TransAmount
into  
	#OraTransData  
from  
	Table_OraTransSum  
where  
	CPDate >= @StartDate  
	and  
	CPDate < @EndDate;
  
--3. determin rule type  
--3.1 get daily trans with ApplyDate  
select  
	Ora.BankSettingID,  
	Ora.MerchantNo,  
	Ora.CPDate,
	Ora.TransCount,
	Ora.TransAmount,
	case when CostRule.FeeType = 'PerCnt' 
			  then Ora.TransCount * CostRule.FeeValue 
		 else 0 End as TransCost
--into  
--	#CostResult  
from  
	#OraTransData Ora 
	left join  
	Table_OraBankCostRule CostRule  
	on  
		Ora.BankSettingID = CostRule.BankSettingID  
		and  
		Ora.CPDate >= CostRule.ApplyStartDate
		and
		Ora.CPDate <  DateAdd(day,1,ISNULL(CostRule.ApplyEndDate,@MaxDate));  
     
----3.4 Get Result
--select  
--	BankSettingID,  
--	MerchantNo,   
--	SUM(TransCnt) TransCnt,  
--	Convert(decimal,SUM(TransAmt))/100 TransAmt,   
--	Convert(decimal,SUM(TransCost))/100 as TransCost   
--from  
--	#CostResult  
--group by  
--	BankSettingID,  
--	MerchantNo;
  
--6. clear temp table   
drop table #OraTransData;  
--drop table #CostResult;  
  
end