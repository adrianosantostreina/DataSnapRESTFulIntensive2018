object ServerMethods1: TServerMethods1
  OldCreateOrder = False
  Height = 286
  Width = 428
  object fdConn: TFDConnection
    Params.Strings = (
      'Database=curso'
      'User_Name=curso'
      'Password=s32]4]381a'
      'Server=192.168.1.90'
      'DriverID=MySQL')
    Left = 88
    Top = 48
  end
  object qryExportar: TFDQuery
    Connection = fdConn
    Left = 88
    Top = 120
  end
  object FDPhysMySQLDriverLink1: TFDPhysMySQLDriverLink
    Left = 280
    Top = 48
  end
  object FDStanStorageJSONLink1: TFDStanStorageJSONLink
    Left = 280
    Top = 120
  end
end
