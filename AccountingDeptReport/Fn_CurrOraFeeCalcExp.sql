if OBJECT_ID(N'Fn_CurrOraFeeCalcExp',N'FN') is not null
begin
	drop function Fn_CurrOraFeeCalcExp;
end
go

create function Fn_CurrOraFeeCalcExp
(
	@MerchantNo varchar(20) = '305440359609700'
)
returns nvarchar(200)
as
begin
	declare @FeeCalcExp nvarchar(200);
	if exists (
		select
			1
		from
			Table_OraOrdinaryMerRate OrdiMerRate
		where
			OrdiMerRate.MerchantNo = @MerchantNo
			and
			OrdiMerRate.StartDate <= getdate()
			and
			OrdiMerRate.EndDate > getdate())
	begin
		select @FeeCalcExp = stuff(
			(select
			'，' +
			case when 
				OrdiMerRate.RefType = 'PerCnt'
			then 
				N'每笔手续费' + convert(varchar, convert(decimal(20, 2), OrdiMerRate.FeeValue/100.0)) + N'元'
			when
				OrdiMerRate.RefType = 'MonthCnt' 
			then 
				N'每月总交易笔数在'+ convert(varchar,  OrdiMerRate.RefMin/10000)
				+ case when 
					OrdiMerRate.RefMax != 100000000000000
				then 
					'-' + convert(nvarchar, OrdiMerRate.RefMax/10000) + N'万笔时，'
				else
					N'以上时，'
				end	
				+ N'每笔手续费' + convert(varchar, convert(decimal(20, 2), OrdiMerRate.FeeValue/100.0)) + N'元'
			when 
				OrdiMerRate.RefType = 'Percent' 
			then
				N'按金额的' + convert(varchar, convert(decimal(20, 2), OrdiMerRate.FeeValue * 100)) + N'%收取手续费' 
				+ case when 
						OrdiMerRate.RefMin > 0 
					then 
						N'，封底' + convert(varchar, convert(decimal(20, 2), OrdiMerRate.RefMin/100)) + N'元' 
					end
				+ case when 
						OrdiMerRate.RefMax != @MerchantNo
					then 
						N'，封顶' + convert(varchar,convert(decimal(20, 2), OrdiMerRate.RefMax/100)) + N'元' 
					end
			End
		from
			Table_OraOrdinaryMerRate OrdiMerRate
		where
			OrdiMerRate.MerchantNo = @MerchantNo
			and
			OrdiMerRate.StartDate <= getdate()
			and
			OrdiMerRate.EndDate > getdate()
		for xml path('')),
		1,
		1,
		'')
	end		
	else if exists (
		select
			1
		from
			Table_OraBankMerRate BankMerRate
		where
			BankMerRate.MerchantNo = @MerchantNo
			and
			BankMerRate.StartDate <= getdate()
			and
			BankMerRate.EndDate > getdate())
	begin
		select @FeeCalcExp =stuff(
			(select  
			'，' +
				REPLACE(LEFT(BankName,2),N'%','') + N'行每笔' + convert(varchar, convert(decimal(20, 2), BankMerRate.FeeValue/100.0)) + N'元'
			from
				Table_OraBankMerRate BankMerRate
			where
				BankMerRate.MerchantNo = @MerchantNo
				and
				BankMerRate.StartDate <= getdate()
				and
				BankMerRate.EndDate > getdate()
			FOR XML PATH('')
			),
			1,
			1,
			'')
	end
	else
	begin
		set @FeeCalcExp = N'';
	end

	return @FeeCalcExp;
end


