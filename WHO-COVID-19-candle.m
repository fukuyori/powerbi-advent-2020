let
    ソース = 
        Csv.Document(
            Web.Contents("https://covid19.who.int/WHO-COVID-19-global-data.csv"),
            [Delimiter=",", 
            Columns=8, 
            Encoding=65001, 
            QuoteStyle=QuoteStyle.None]
        ),
    昇格されたヘッダー数 = 
        Table.PromoteHeaders(
            ソース, 
            [PromoteAllScalars=true]
        ),
    Date_reportedを日付に変更 = 
        Table.TransformColumnTypes(
            昇格されたヘッダー数,
            {
                {"Date_reported", type date}, 
                {"Country_code", type text}, 
                {"Country", type text}, 
                {"WHO_region", type text}, 
                {"New_cases", Int64.Type}, 
                {"Cumulative_cases", Int64.Type}, 
                {"New_deaths", Int64.Type}, 
                {"Cumulative_deaths", Int64.Type}
            }
        ),
    削除された列 = 
        Table.RemoveColumns(
            Date_reportedを日付に変更,
            {
                "Country_code", 
                "WHO_region", 
                "Cumulative_cases", 
                "Cumulative_deaths"
            }
        ),
    名前が変更された列 = 
        Table.RenameColumns(
            削除された列,
            {
                {
                    "New_cases", 
                    "新規感染者数"
                }
            }
        ),
    日付ごとにグループ化 = 
        Table.Group(
            名前が変更された列, 
            {
                "Date_reported"
            }, 
            {
                {
                    "新規感染者数", 
                    each List.Sum([新規感染者数]), 
                    type nullable number
                }
            }
        ),
    WeekOfYearを追加 = 
        Table.AddColumn(
            日付ごとにグループ化,
            "WeekOfYear", 
            each Date.Year([Date_reported]) * 100 + Date.WeekOfYear([Date_reported])
        ),
    DayOfWeekを追加 = 
        Table.AddColumn(
            WeekOfYearを追加,
            "DayOfWeek", 
            each Date.DayOfWeek([Date_reported])
        ),
    //
    // もっとも古い日付と、もっとも新しい日付を取得
    EarliestDay = List.Min(DayOfWeekを追加[Date_reported]),
    LatestDay = List.Max(DayOfWeekを追加[Date_reported]),
    //
    Openを追加 = 
        Table.AddColumn(
            DayOfWeekを追加,
            "Open", 
            each 
                if [Date_reported] = EarliestDay or [DayOfWeek] = 0 then 
                    [新規感染者数] 
                else 
                    0
        ),
    Closeを追加 = 
        Table.AddColumn(
            Openを追加, 
            "Close", 
            each 
                if [Date_reported] = LatestDay or [DayOfWeek] = 6 then 
                    [新規感染者数] 
                else 
                    0
        ),
    //
    WeekOfYearでグループ化 = 
        Table.Group(
            Closeを追加,
            {"WeekOfYear"}, 
            {
                {
                    "Open", 
                    each List.Sum([Open]), 
                    type number}
                , 
                {
                    "Close", 
                    each List.Sum([Close]), 
                    type number
                }, 
                {
                    "High", 
                    each List.Max([新規感染者数]), 
                    type nullable number
                }, 
                {
                    "Low", 
                    each List.Min([新規感染者数]), 
                    type nullable number
                }
            }
        ),
    // WeekOfYearの頭4桁の年の最初の週の1日目を取得(2020年は2019年12月29日) 
    // それにWeekOfYearの下二けたの数字に7をかけた日付を加える
    Dateを追加 =
        Table.AddColumn(
            WeekOfYearでグループ化,
            "date", 
            each 
                Date.AddDays(
                    #date(Int32.From([WeekOfYear] / 100),1,1),
                    Date.DayOfWeek(
                        #date(Int32.From([WeekOfYear] / 100),1,1)
                    ) * -1 + (Number.Mod([WeekOfYear],100) - 1) *7
                )
        ),
    Dateを日付に変更 =
        Table.TransformColumnTypes(
            Dateを追加,
            {
                {"date", type date}
            }
        )
in
    Dateを日付に変更