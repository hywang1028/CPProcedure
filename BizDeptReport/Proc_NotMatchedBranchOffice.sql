--[Modified] at 2012-07-13 by ������  Description:Add Financial Dept Configuration Data
--[Modified] at 2012-12-13 by �����  Description:Add Type N'�����֧����'
if OBJECT_ID(N'Proc_NotMatchedBranchOffice',N'P') is not null
begin
	drop procedure Proc_NotMatchedBranchOffice;
end
go

create procedure Proc_NotMatchedBranchOffice
	@Type nvarchar(10)= N'�����֧����'
as
begin

--1.Check Input
if (ISNULL(@Type,N'') = N'')
begin
	raiserror('Input Parameters can`t be empty in Proc_NotMatchedBranchOffice!',16,1);
end	

--2.0 Prepare All Mer Name
select
	coalesce(PayMer.MerchantNo,OraMer.MerchantNo) MerchantNo,
	coalesce(PayMer.MerchantName,OraMer.MerchantName) MerchantName
into
	#AllMerName
from
	Table_MerInfo PayMer
	full outer join
	Table_OraMerchants OraMer
	on
		PayMer.MerchantNo = OraMer.MerchantNo;

--2.1 Get Ums&UnionPay Not Matched BranchOffice
if @Type = N'�������̷�֧����'
begin

select
	N'���۲�' as DataSupport,
	SalesDeptConfig.BranchOffice,
	SalesDeptConfig.MerchantName,
	SalesDeptConfig.MerchantNo
from
	Table_SalesDeptConfiguration SalesDeptConfig
	left join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		SalesDeptConfig.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
where
	ISNULL(BranchOfficeNameRule.UnnormalBranchOfficeName,N'') = N''
	and
	(
		SalesDeptConfig.Channel = N'����'
		or
		SalesDeptConfig.Channel = N'����'
	)
union all
select
	N'���ڲ�' as DataSupport,
	Finance.BranchOffice,
	(select MerchantName from #AllMerName where MerchantNo = Finance.MerchantNo) MerchantName,
	Finance.MerchantNo
from
	Table_FinancialDeptConfiguration Finance
	left join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		Finance.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
where
	ISNULL(BranchOfficeNameRule.UnnormalBranchOfficeName,N'') = N''
	and
	(
		Finance.Channel = N'����'
		or
		Finance.Channel = N'����'
	);

end


--3.Get Not Matched BranchOffice Whose Channel is CP
if(@Type = N'������֧����')
begin

select distinct
	N'���۲�' DataSupport,
	BranchOffice,
	MerchantName,
	MerchantNo
from
	Table_SalesDeptConfiguration
where
	Channel not in (N'����',N'����')
	and
	ISNULL(BranchOffice,N'') <> N''
union all
select distinct
	N'���ڲ�' DataSupport,
	BranchOffice,
	(select MerchantName from #AllMerName where MerchantNo = Table_FinancialDeptConfiguration.MerchantNo) MerchantName,
	MerchantNo
from
	Table_FinancialDeptConfiguration
where
	Channel not in (N'����',N'����')
	and
	ISNULL(BranchOffice,N'') <> N'';;

end


--4.Get Not Matched BranchOffice From Emall Data
if(@Type = N'�̳Ƿ�֧����')
begin

select
	N'�̳�' as DataSupport,
	EmallTransSum.BranchOffice,
	EmallTransSum.MerchantName,
	EmallTransSum.MerchantNo
from
	Table_EmallTransSum EmallTransSum
	left join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		EmallTransSum.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
where
	ISNULL(BranchOfficeNameRule.UnnormalBranchOfficeName,N'') = N''
	and
	isnull(EmallTransSum.BranchOffice, N'') not in (N'ChinaPay', N'Chinova', N'Shopex');

end		

--5.Get Not Matched BranchOffice From CP Area
if(@Type = N'�����������̻�����')	
begin

select
	N'���۲�' as DataSupport,
	SalesDeptConfiguration.Area as BranchOffice,
	SalesDeptConfiguration.MerchantName,
	SalesDeptConfiguration.MerchantNo
from
	Table_SalesDeptConfiguration SalesDeptConfiguration
	left join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		SalesDeptConfiguration.Area = BranchOfficeNameRule.BranchOfficeShortName
where
	BranchOfficeNameRule.BranchOfficeShortName is null
	and
	SalesDeptConfiguration.Channel not in (N'����',N'����')
union all
select
	N'���ڲ�' as DataSupport,
	Finance.Area as BranchOffice,
	(select MerchantName from #AllMerName where MerchantNo = Finance.MerchantNo) MerchantName,
	Finance.MerchantNo
from
	Table_FinancialDeptConfiguration Finance
	left join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		Finance.Area = BranchOfficeNameRule.BranchOfficeShortName
where
	BranchOfficeNameRule.BranchOfficeShortName is null
	and
	Finance.Channel not in (N'����',N'����');
end


--6.Get Not Matched BranchOffice From Table_UMSBranchFundTrans Data 
if(@Type = N'�����֧����')   
begin  
select
	N'���ڲ�' as DataSupport,
	UMS.BranchOfficeName as BranchOffice,
	UMS.TransDate as MerchantName,
	SUM(UMS.B2CPurchaseAmt + UMS.B2CRedemptoryAmt + UMS.B2BPurchaseAmt + UMS.B2BRedemptoryAmt)/100.0 as MerchantNo
from
	Table_UMSBranchFundTrans UMS
	left join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		UMS.BranchOfficeName = BranchOfficeNameRule.UnnormalBranchOfficeName
where
	ISNULL(BranchOfficeNameRule.UnnormalBranchOfficeName,N'') = N'' 
group by
	UMS.BranchOfficeName,
	UMS.TransDate;
end

Drop table #AllMerName;
end