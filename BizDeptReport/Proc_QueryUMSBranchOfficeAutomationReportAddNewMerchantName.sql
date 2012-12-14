IF OBJECT_ID(N'Proc_QueryUMSBranchOfficeAutomationReportNewMerchantName',N'p') is not null
begin
	drop procedure Proc_QueryUMSBranchOfficeAutomationReportNewMerchantName
end
go

create procedure Proc_QueryUMSBranchOfficeAutomationReportNewMerchantName
	@StartDate datetime = '2012-09-02',
	@BranchName char(35) = N'北京银联商务有限公司'

as
begin

declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';  
set @CurrEndDate = DATEADD(MONTH,1,@CurrStartDate);  

--1. Check input  
if (@StartDate is null or @BranchName is null)  
begin  
	raiserror(N'Input params cannot be empty in Proc_QueryUMSBranchOfficeAutomationReportNewMerchantName', 16, 1)  
end  

	
select  
	SalesDeptConfiguration.MerchantNo,
	BranchOfficeNameRule.UmsSpec 
into
	#BranchOfficeNewMerchantName
from  
	Table_SalesDeptConfiguration SalesDeptConfiguration  
	inner join  
	Table_BranchOfficeNameRule BranchOfficeNameRule  
on  
	SalesDeptConfiguration.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName  
where  
	BranchOfficeNameRule.UmsSpec = @BranchName  
union  
select   
	Finance.MerchantNo,
	BranchOfficeNameRule.UmsSpec 
from  
	Table_FinancialDeptConfiguration Finance  
	inner join  
	Table_BranchOfficeNameRule BranchOfficeNameRule  
on  
	Finance.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName  
where  
	BranchOfficeNameRule.UmsSpec = @BranchName;


select 
	Table_MerOpenAccountInfo.MerchantNo,
	Table_MerOpenAccountInfo.MerchantName
from	
	Table_MerOpenAccountInfo
	inner join
	#BranchOfficeNewMerchantName
	on
		Table_MerOpenAccountInfo.MerchantNo = #BranchOfficeNewMerchantName.MerchantNo
where
	Table_MerOpenAccountInfo.OpenAccountDate >= @CurrStartDate
	and
	Table_MerOpenAccountInfo.OpenAccountDate < @CurrEndDate;


end

