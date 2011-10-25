if OBJECT_ID(N'Proc_NotMatchedBranchOffice',N'P') is not null
begin
	drop procedure Proc_NotMatchedBranchOffice;
end
go

create procedure Proc_NotMatchedBranchOffice
	@Type nvarchar(5)= N'�̳�'
as
begin

--1.Check Input
if (ISNULL(@Type,N'') = N'')
begin
	raiserror('Input Parameters can`t be empty in Proc_NotMatchedBranchOffice!',16,1);
end	
	
	
--2.Get Ums&UnionPay Not Matched BranchOffice
if @Type = N'��������'
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
	);

end


--3.Get Not Matched BranchOffice Whose Channel is CP
if(@Type = N'CP')
begin

select distinct
	N'���۲�' DataSupport,
	BranchOffice,
	MerchantName,
	MerchantNo
from
	Table_SalesDeptConfiguration
where
	Channel = N'CP'
	and
	ISNULL(BranchOffice,N'') <> N'';
	
end


--4.Get Not Matched BranchOffice From Emall Data
if(@Type = N'�̳�')
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
			
end