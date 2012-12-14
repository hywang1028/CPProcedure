IF OBJECT_ID(N'Proc_QueryUMSBranchOfficeAutomationReportNameInforAmtCntFinalAmt',N'p') is not null
begin
	drop procedure Proc_QueryUMSBranchOfficeAutomationReportNameInforAmtCntFinalAmt
end
go

create procedure Proc_QueryUMSBranchOfficeAutomationReportNameInforAmtCntFinalAmt
	@StartDate datetime = '2012-10-22',
	@BranchName Nvarchar(35) = N'�����������޹�˾���շֹ�˾'


as  
begin

declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
declare @ThisYearStartDate datetime;
set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';  
set @CurrEndDate = DATEADD(MONTH,1,@CurrStartDate);  
set @ThisYearStartDate = CONVERT(char(4),YEAR(@CurrStartDate)) + '-01-01';

--1. Check input  
if (@StartDate is null or @BranchName is null)  
begin  
	raiserror(N'Input params cannot be empty in Proc_QueryUMSBranchOfficeAutomationReportNameInforAmtCntFinalAmt', 16, 1)  
end  


--1.Result
select  
	UMS.MonthDate,
	case when
		UMS.SalesBrief = ''
	then
		N'���ص��̻����ָ��ٻط�,��֤�������Ȳ�����'
	else
		UMS.SalesBrief
	end
		SalesBrief,
	UMS.ShortName,
	UMS.BranchOfficeName,
	UMS.TransAmt,
	UMS.TransCnt,
	(
		select 
			SUM(TransAmt)
		from 
			Table_UMSBranchRptDetailConfig 
		where 
			BranchOfficeName = @BranchName
			and
			MonthDate >= @ThisYearStartDate
			and 
			MonthDate < @CurrEndDate
	) as Accumulate,
	UMS.InstuFeeAmt,
	UMS.ReceivableAmt,
	UMS.AgreementCnt,
	UMS.AgreementPassCnt,
	UMS.AgreementRetreatCnt,
	UMS.BizSuggest,
	UMS.SalesContact,
	UMS.SalesPhone,
	UMS.SalesMobile,
	UMS.SalesEmail
from
	Table_UMSBranchRptDetailConfig UMS
where
	BranchOfficeName = @BranchName
	and
	MonthDate >= @CurrStartDate
	and
	MonthDate < @CurrEndDate;


end