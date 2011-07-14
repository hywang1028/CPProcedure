With TransWithCardNo as
(
	select
		TransDate,
		MerchantNo,
		TransType,
		TransAmt,
		FeeAmt,
		FundType,
		case when
			TransType in ('1010','3010')
		then
			CardID
		else
			CardTwo
		end CardNo
	from
		dbo.Table_TrfTransLog
	where
		TransType in ('1010','3010','3020','3030','3040','3050')
)
select
	TransWithCardNo.TransDate,
	TransWithCardNo.MerchantNo,
	FundCardBin.BankNo,
	Left(Right(TransWithCardNo.CardNo,LEN(TransWithCardNo.CardNo)-LEN(FundCardBin.CardBin)),2) as BranchNo,
	TransWithCardNo.TransType,
	TransWithCardNo.FundType,
	Sum(TransWithCardNo.TransAmt) as TransAmount,
	COUNT(TransWithCardNo.TransAmt) as TransCount,
	SUM(TransWithCardNo.FeeAmt) as FeeAmount
into
	#ResultTable
from
	TransWithCardNo
	left join
	dbo.Table_FundCardBin FundCardBin
	on
		TransWithCardNo.CardNo like (RTrim(FundCardBin.CardBin)+'%')
	left join
	dbo.Table_FundBankBranch FundBankBranch
	on
		FundCardBin.BankNo = FundBankBranch.BankNo
		and
		Left(Right(TransWithCardNo.CardNo,LEN(TransWithCardNo.CardNo)-LEN(FundCardBin.CardBin)),2) like RTrim(FundBankBranch.BankBranchNo)
where
	FundCardBin.CardBin is not null
group by
	TransWithCardNo.TransDate,
	TransWithCardNo.MerchantNo,
	FundCardBin.BankNo,
	Left(Right(TransWithCardNo.CardNo,LEN(TransWithCardNo.CardNo)-LEN(FundCardBin.CardBin)),2),
	TransWithCardNo.FundType,
	TransWithCardNo.TransType
order by
	TransWithCardNo.TransDate,
	TransWithCardNo.MerchantNo,
	FundCardBin.BankNo;
	
select
	Result.*,
	BankID.BankName,
	FundBankBranch.BankBranchName
from
	#ResultTable Result
	left join
	Table_BankID BankID
	on
		Result.BankNo = BankID.BankNo
	left join
	Table_FundBankBranch FundBankBranch
	on
		Result.BranchNo = FundBankBranch.BankBranchNo
		
drop table #ResultTable;