--[Created] At 20120308 By 叶博：ORA成本子存储过程
--Input:StartDate,EndDate
--Output:BankSettingID,MerchantNo,CPDate,TransCnt,TransAmt,CostAmt
--[Modified] At 20120322 By 王红燕：Add @HisRefDate Parameter
if OBJECT_ID(N'Proc_CalOraCost', N'P') is not null
begin
	drop procedure Proc_CalOraCost;
end
go 

create procedure Proc_CalOraCost  
 @StartDate datetime = '2011-06-01',  
 @EndDate datetime = '2011-07-01',
 @HisRefDate datetime = null
as  
begin  

--1. CheckInput  
if(@StartDate is null or @EndDate is null)  
begin  
 raiserror(N'Input params can`t be empty in Proc_CalOraCost',16,1);  
end  
  
--2. Get Ora Trans  
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
  
--3. Calculate Ora Cost
if(@HisRefDate is not null)
begin
With BankNewApplyDate as
(
	select 
		BankSettingID,
		MIN(ApplyStartDate) ApplyStartDate
	from
		Table_OraBankCostRule
	where 
		ApplyStartDate < @EndDate
	group by
		BankSettingID
),
BankOldApplyDate as
(
	select
		BankSettingID,
		MAX(ApplyStartDate) ApplyStartDate
	from
		Table_OraBankCostRule
	where
		ApplyStartDate <= @HisRefDate
	group by
		BankSettingID
),
ActuallyApplyDate as
(
	select
		New.BankSettingID,
		coalesce(Old.ApplyStartDate,New.ApplyStartDate) ApplyStartDate
	from
		BankNewApplyDate New
		left join
		BankOldApplyDate Old
		on
			New.BankSettingID = Old.BankSettingID
),
CostRule as
(
	select
		Actually.BankSettingID,
		Actually.ApplyStartDate,
		Ora.FeeType,
		Ora.FeeValue,
		@EndDate as ApplyEndDate
	from
		ActuallyApplyDate Actually
		inner join
		Table_OraBankCostRule Ora
		on
			Actually.BankSettingID = Ora.BankSettingID
			and 
			Actually.ApplyStartDate = Ora.ApplyStartDate
)
select  
	Ora.BankSettingID,  
	Ora.MerchantNo,  
	Ora.CPDate,
	Ora.TransCount TransCnt,
	Ora.TransAmount TransAmt,
	case when 
			CostRule.FeeType = 'PerCnt' 
		 then
			Ora.TransCount * CostRule.FeeValue 
		 else
			0 
	End as CostAmt
from  
	#OraTransData Ora 
	left join  
	CostRule  
	on  
		Ora.BankSettingID = CostRule.BankSettingID  
		and  
		Ora.CPDate >= CostRule.ApplyStartDate
		and
		Ora.CPDate <  CostRule.ApplyEndDate
End
else
Begin
select  
	Ora.BankSettingID,  
	Ora.MerchantNo,  
	Ora.CPDate,
	Ora.TransCount TransCnt,
	Ora.TransAmount TransAmt,
	case when 
			CostRule.FeeType = 'PerCnt' 
		 then
			Ora.TransCount * CostRule.FeeValue 
		 else
			0 
	End as CostAmt
from  
	#OraTransData Ora 
	left join  
	Table_OraBankCostRule CostRule  
	on  
		Ora.BankSettingID = CostRule.BankSettingID  
		and  
		Ora.CPDate >= CostRule.ApplyStartDate
		and
		Ora.CPDate <  CostRule.ApplyEndDate;  
End   
  
--4. clear temp table   
drop table #OraTransData;  
  
end