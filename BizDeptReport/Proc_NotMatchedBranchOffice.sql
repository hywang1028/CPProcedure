if OBJECT_ID(N'Proc_NotMatchedBranchOffice',N'P') is not null
begin
	drop procedure Proc_NotMatchedBranchOffice;
end
go

create procedure Proc_NotMatchedBranchOffice
	@Type nvarchar(10)= N'非银联银商商户地区'
as
begin

--1.Check Input
if (ISNULL(@Type,N'') = N'')
begin
	raiserror('Input Parameters can`t be empty in Proc_NotMatchedBranchOffice!',16,1);
end	
	
	
--2.Get Ums&UnionPay Not Matched BranchOffice
if @Type = N'银联银商分支机构'
begin

select
	N'销售部' as DataSupport,
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
		SalesDeptConfig.Channel = N'银联'
		or
		SalesDeptConfig.Channel = N'银商'
	);

end


--3.Get Not Matched BranchOffice Whose Channel is CP
if(@Type = N'其他分支机构')
begin

select distinct
	N'销售部' DataSupport,
	BranchOffice,
	MerchantName,
	MerchantNo
from
	Table_SalesDeptConfiguration
where
	Channel not in (N'银联',N'银商')
	and
	ISNULL(BranchOffice,N'') <> N'';

end


--4.Get Not Matched BranchOffice From Emall Data
if(@Type = N'商城分支机构')
begin

select
	N'商城' as DataSupport,
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
if(@Type = N'非银联银商商户地区')	
begin

select
	N'销售部' as DataSupport,
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
	SalesDeptConfiguration.Channel not in (N'银联',N'银商');
			
end

end