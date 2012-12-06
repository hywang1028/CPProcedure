--[Created] at 2012-07-20 by 王红燕  Description:Compare Sales Dept Configuration and Financial Dept Configuration
if OBJECT_ID(N'Proc_DeptMerInfoCheck',N'P') is not null
begin
	drop procedure Proc_DeptMerInfoCheck;
end
go

create procedure Proc_DeptMerInfoCheck
as
begin

--1.Check Input
	
--2.0 Prepare All Mer Name
With RepeatedMer as
(
	select
		Sales.MerchantNo
	from
		Table_SalesDeptConfiguration Sales
		inner join
		Table_FinancialDeptConfiguration Finance
		on
			Sales.MerchantNo = Finance.MerchantNo
),
AllMerName as
(
	select
		coalesce(PayMer.MerchantNo,OraMer.MerchantNo) MerchantNo,
		coalesce(PayMer.MerchantName,OraMer.MerchantName) MerchantName
	from
		Table_MerInfo PayMer
		full outer join
		Table_OraMerchants OraMer
		on
			PayMer.MerchantNo = OraMer.MerchantNo
	where
		coalesce(PayMer.MerchantNo,OraMer.MerchantNo) in (select MerchantNo from RepeatedMer) 
),
--2.1 Get Ums&UnionPay Not Matched BranchOffice
AllBranchMer as
(
	select
		SalesDeptConfig.MerchantNo,
		N'销售部' as DataSupport,
		BranchOfficeNameRule.NormalBranchOfficeName BranchOffice,
		SalesDeptConfig.Area
	from
		Table_SalesDeptConfiguration SalesDeptConfig
		left join
		Table_BranchOfficeNameRule BranchOfficeNameRule
		on
			SalesDeptConfig.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
	where
		SalesDeptConfig.MerchantNo in (select MerchantNo from RepeatedMer) 
	union all
	select
		Finance.MerchantNo,
		N'金融部' as DataSupport,
		BranchOfficeNameRule.NormalBranchOfficeName BranchOffice,
		Finance.Area
	from
		Table_FinancialDeptConfiguration Finance
		left join
		Table_BranchOfficeNameRule BranchOfficeNameRule
		on
			Finance.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
	where
		Finance.MerchantNo in (select MerchantNo from RepeatedMer) 
),
SameInfo as
(
	select
		MerchantNo
	from
		AllBranchMer
	group by
		MerchantNo,
		BranchOffice,
		Area
	having
		COUNT(*) > 1
)
select
	MerchantNo,
	(select MerchantName from AllMerName where MerchantNo = AllBranchMer.MerchantNo) MerchantName,
	DataSupport,
	BranchOffice,
	Area
from
	AllBranchMer
where
	MerchantNo not in (select MerchantNo from SameInfo)
order by
	MerchantNo,
	DataSupport;

end
