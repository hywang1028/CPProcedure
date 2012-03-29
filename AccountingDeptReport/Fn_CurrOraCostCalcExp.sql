--[Created] At 20120328 By chen.wu
--Input:BankSettingID 
--Output:Show ORA Cost Calculation Expression

if OBJECT_ID(N'Fn_CurrOraCostCalcExp',N'FN') is not null
begin
	drop function Fn_CurrOraCostCalcExp;
end
go

create function Fn_CurrOraCostCalcExp
(
	@BankSettingID varchar(10)
)
returns nvarchar(200)
as
begin
	declare @CostCalcExp nvarchar(200);
	select 
		@CostCalcExp = case when
			FeeType = 'PerCnt'
		then
			N'µ¥±Ê' + convert(varchar, convert(decimal(14, 2), FeeValue/100.0)) + N'Ôª'
		else
			N''
		end
	from
		Table_OraBankCostRule
	where
		BankSettingID = @BankSettingID
		and
		ApplyStartDate <= GETDATE()
		and
		ApplyEndDate > GETDATE()	

	return @CostCalcExp;
end


