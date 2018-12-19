unit ServerMethodsUnit1;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Json,

  DataSnap.DSProviderDataModuleAdapter,
  Datasnap.DSServer,
  Datasnap.DSAuth,

  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.MySQL,
  FireDAC.Phys.MySQLDef,
  FireDAC.VCLUI.Wait,
  FireDAC.Stan.Param,
  FireDAC.DatS,
  FireDAC.DApt.Intf,
  FireDAC.DApt,
  FireDAC.Stan.StorageJSON,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,

  Data.DB,

  Datasnap.DSHTTPWebBroker,
  Web.HTTPapp,

  ULGTDataSetHelper;

type
  TServerMethods1 = class(TDSServerModule)
    fdConn: TFDConnection;
    qryExportar: TFDQuery;
    FDPhysMySQLDriverLink1: TFDPhysMySQLDriverLink;
    FDStanStorageJSONLink1: TFDStanStorageJSONLink;
  private
    { Private declarations }
    procedure FormatarJSON(const AIDCode: Integer; const AContent: string);
  public
    { Public declarations }
    function EchoString(Value: string): string;
    function ReverseString(Value: string): string;
    // Nossas funções
    function Pedidos(idpedido : string) : TJSONArray;
    function AcceptPedidos(const AIDPedido: integer): TJSONArray;
    function UpdatePedidos : TJSONArray;
    function CancelPedidos (const AIDPedido: integer): TJSONArray;

  end;

implementation


{$R *.dfm}


uses System.StrUtils, Data.DBXPlatform;

function TServerMethods1.AcceptPedidos(const AIDPedido: integer): TJSONArray; // Update no REST
(*
begin

  Result := TJSONArray.Create('UPDATE - PUT', 'REST');
  GetInvocationMetadata().ResponseContent := Result.ToString;
  GetInvocationMetadata().ResponseCode := 200;
*)

const
  UPD_PEDIDO =
    'UPDATE CURSO.PEDIDOS SET                         ' +
    '   ID_USUARIO          =  :ID_USUARIO          , ' +
    '   ID_ESTABELECIMENTO  =  :ID_ESTABELECIMENTO  , ' +
    '   DATA                =  :DATA                , ' +
    '   STATUS              =  :STATUS              , ' +
    '   VALOR_PEDIDO        =  :VALOR_PEDIDO        , ' +
    '   ID_PEDIDO_MOBILE    =  :ID_PEDIDO_MOBILE      ' +
    'WHERE                                            ' +
    '   ID = :pID                                     ';

var
  lModulo               : TWebModule;
  lJARequisicao         : TJSONArray;
  LValores              : TJSONValue;
  jPedido               : TJSONValue;
  jItens                : TJSONValue;
  lJOBJ                 : TJSONObject;

  //Pedidos
  iId_Pedido_Mobile     : Integer;
  iId_Uuario            : Integer;
  iId_Estabelecimento   : Integer;
  dData                 : TDateTime;
  fValor_Pedido         : Double;

  //Itens pedido
  iQtde                 : Integer;
  fValor_Unitario       : Double;
  iId_Cardapio          : Integer;

  //Auxiliares
  I                     : Integer;
  J                     : Integer;
  arrItens              : Integer;
  iID_PedidoGerado      : Integer;
begin
  //Verbo HTTP : POST
  //INSERT INTO na tabela
  lModulo := GetDataSnapWebModule;
  if lModulo.Request.Content.IsEmpty then
  begin
    GetInvocationMetaData().ResponseCode := 204;
    Abort;
  end;

  lJARequisicao := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(lModulo.Request.Content), 0) as TJSONArray;

  try
    fdConn.TxOptions.AutoCommit := False;
    if not fdConn.InTransaction  then
      fdConn.StartTransaction;

    for LVAlores in lJARequisicao do
    begin
      jPedido := LValores.GetValue<TJSONArray>('pedido');
      for I := 0 to Pred((jPedido as TJSONArray).Count) do
      begin
        iId_Pedido_Mobile   := (jPedido as TJSONArray).Items[I].GetValue<integer>('id_pedido_mobile');
        iId_Uuario          := (jPedido as TJSONArray).Items[I].GetValue<integer>('id_usuario');
        iId_Estabelecimento := (jPedido as TJSONArray).Items[I].GetValue<integer>('id_estabelecimento');
        dData               := StrToDateTime((jPedido as TJSONArray).Items[I].GetValue<string>('data'));
        fValor_Pedido       := (jPedido as TJSONArray).Items[I].GetValue<double>('valor_pedido');

        //Inclusão de Pedidos
        qryExportar.Active := False;
        qryExportar.SQL.Clear;
        qryExportar.SQL.Text := UPD_PEDIDO;

        qryExportar.ParamByName('pID').AsInteger                := AIDPedido;
        qryExportar.ParamByName('ID_USUARIO').AsInteger         := iId_Uuario;
        qryExportar.ParamByName('ID_ESTABELECIMENTO').AsInteger := iId_Estabelecimento;
        qryExportar.ParamByName('DATA').AsDateTime              := dData;
        qryExportar.ParamByName('STATUS').AsString              := 'E';
        qryExportar.ParamByName('VALOR_PEDIDO').AsFloat         := (FormatFloat('###,###,##0.00', fValor_Pedido)).ToDouble();
        qryExportar.ParamByName('ID_PEDIDO_MOBILE').AsInteger   := iId_Pedido_Mobile;

        qryExportar.ExecSQL;
      end;
    end;

    if fdConn.InTransaction then
      fdConn.CommitRetaining;

    fdConn.TxOptions.AutoCommit := True;

    lJOBJ := TJSONObject.Create;
    lJOBJ.AddPair('Mensagem', 'Pedido alterado com sucesso!');

    Result := TJSONArray.Create;
    Result.AddElement(lJOBJ);

    GetInvocationMetaData().ResponseCode := 201;

    FormatarJSON(GetInvocationMetadata().ResponseCode, Result.ToJSON());
  except on E:Exception do
    begin
      fdConn.Rollback;
      raise;
    end;
  end;
end;

function TServerMethods1.CancelPedidos(const AIDPedido: integer): TJSONArray; // Delete no REST
(*
begin
  Result := TJSONArray.Create('DELETE - DELETE', 'REST');
  GetInvocationMetadata().ResponseContent := Result.ToString;
  GetInvocationMetadata().ResponseCode := 200;
*)

const
  SQL = 'DELETE FROM CURSO.PEDIDOS WHERE ID = :pID';
var
  lJOBJ : TJSONObject;
begin
  try
    qryExportar.Active := False;
    qryExportar.SQL.Clear;
    qryExportar.SQL.Text := SQL;
    qryExportar.ParamByName('pID').AsInteger := AIDPedido;
    qryExportar.ExecSQL;

    lJOBJ := TJSONObject.Create;
    lJOBJ.AddPair('Mensagem', 'Pedido cancelado com sucesso!');

    Result := TJSONArray.Create;
    Result.AddElement(lJOBJ);

    GetInvocationMetaData().ResponseCode := 201;

    FormatarJSON(GetInvocationMetadata().ResponseCode, Result.ToJSON());
  except

  end;
end;

function TServerMethods1.EchoString(Value: string): string;
begin
  Result := Value;
end;

procedure TServerMethods1.FormatarJSON(const AIDCode: Integer;
  const AContent: string);
begin
  GetInvocationMetadata().ResponseCode    := AIDCode;
  GetInvocationMetadata().ResponseContent :=  AContent;
end;

function TServerMethods1.Pedidos(idpedido : string) : TJSONArray;
(*
var
  lJO : TJSONObject;
begin
  idpedido := '200';
  lJO := TJSONObject.Create;
  lJO.AddPair('Id', TJSONNumber.Create(1));
  lJO.AddPair('Cliente', 'Landerson');
  Result := TJSONArray.Create;
  Result.AddElement(lJO);
  GetInvocationMetadata().ResponseContent := Result.ToString;
*)
const
  _SQL = 'SELECT * FROM CURSO.PEDIDOS';
begin
  qryExportar.Active := False;
  qryExportar.SQL.Clear;
  qryExportar.SQL.Text := _SQL;
  qryExportar.Active := True;

  if qryExportar.IsEmpty
  then Result := TJSONArray.Create('Mensagem', 'Nenhum pedido no servidor.')
  else Result := qryExportar.DataSetToJSON;

  FormatarJSON(GetInvocationMetadata().ResponseCode, Result.ToString);
end;

function TServerMethods1.ReverseString(Value: string): string;
begin
  Result := System.StrUtils.ReverseString(Value);
end;

function TServerMethods1.UpdatePedidos: TJSONArray; // INSERIR no REST
(*
begin

  Result := TJSONArray.Create('INSERIR - POST', 'REST');
  GetInvocationMetadata().ResponseContent := Result.ToString;
  GetInvocationMetadata().ResponseCode := 201;
*)

const
  INS_PEDIDO =
    'INSERT INTO CURSO.PEDIDOS   ' +
    '(                           ' +
    '   ID_USUARIO             , ' +
    '   ID_ESTABELECIMENTO     , ' +
    '   DATA                   , ' +
    '   STATUS                 , ' +
    '   VALOR_PEDIDO           , ' +
    '   ID_PEDIDO_MOBILE         ' +
    ')                           ' +
    'VALUES                      ' +
    '(                           ' +
    '   :ID_USUARIO            , ' +
    '   :ID_ESTABELECIMENTO    , ' +
    '   :DATA                  , ' +
    '   :STATUS                , ' +
    '   :VALOR_PEDIDO          , ' +
    '   :ID_PEDIDO_MOBILE        ' +
    ');                        ';

  INS_ITENS_PEDIDO =
    'INSERT INTO CURSO.ITENS_PEDIDO  ' +
    '(                               ' +
    '   ID_PEDIDO            ,       ' +
    '   QTDE                 ,       ' +
    '   VALOR_UNITARIO       ,       ' +
    '   ID_CARDAPIO          ,       ' +
    '   ID_PEDIDO_MOBILE             ' +
    ')                               ' +
    'VALUES                          ' +
    '(                               ' +
    '   :ID_PEDIDO           ,       ' +
    '   :QTDE                ,       ' +
    '   :VALOR_UNITARIO      ,       ' +
    '   :ID_CARDAPIO         ,       ' +
    '   :ID_PEDIDO_MOBILE            ' +
    ');                              ';

var
  lModulo               : TWebModule;
  lJARequisicao         : TJSONArray;
  LValores              : TJSONValue;
  jPedido               : TJSONValue;
  jItens                : TJSONValue;
  lJOBJ                 : TJSONObject;

  //Pedidos
  iId_Pedido_Mobile     : Integer;
  iId_Uuario            : Integer;
  iId_Estabelecimento   : Integer;
  dData                 : TDateTime;
  fValor_Pedido         : Double;

  //Itens pedido
  iQtde                 : Integer;
  fValor_Unitario       : Double;
  iId_Cardapio          : Integer;

  //Auxiliares
  I                     : Integer;
  J                     : Integer;
  arrItens              : Integer;
  iID_PedidoGerado      : Integer;
begin
  //Verbo HTTP : POST
  //INSERT INTO na tabela
  lModulo := GetDataSnapWebModule;
  if lModulo.Request.Content.IsEmpty then
  begin
    GetInvocationMetaData().ResponseCode := 204;
    Abort;
  end;

  lJARequisicao := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(lModulo.Request.Content), 0) as TJSONArray;

  try
    fdConn.TxOptions.AutoCommit := False;
    if not fdConn.InTransaction  then
      fdConn.StartTransaction;

    for LValores in lJARequisicao do
    begin
      jPedido := LValores.GetValue<TJSONArray>('pedido');
      for I := 0 to Pred((jPedido as TJSONArray).Count) do
      begin
        iId_Pedido_Mobile   := (jPedido as TJSONArray).Items[I].GetValue<integer>('id_pedido_mobile');
        iId_Uuario          := (jPedido as TJSONArray).Items[I].GetValue<integer>('id_usuario');
        iId_Estabelecimento := (jPedido as TJSONArray).Items[I].GetValue<integer>('id_estabelecimento');
        dData               := StrToDateTime((jPedido as TJSONArray).Items[I].GetValue<string>('data'));
        fValor_Pedido       := (jPedido as TJSONArray).Items[I].GetValue<double>('valor_pedido');

        //Inclusão de Pedidos
        qryExportar.Active := False;
        qryExportar.SQL.Clear;
        qryExportar.SQL.Text := INS_PEDIDO;

        qryExportar.ParamByName('ID_USUARIO').AsInteger         := iId_Uuario;
        qryExportar.ParamByName('ID_ESTABELECIMENTO').AsInteger := iId_Estabelecimento;
        qryExportar.ParamByName('DATA').AsDateTime              := dData;
        qryExportar.ParamByName('STATUS').AsString              := 'E';
        qryExportar.ParamByName('VALOR_PEDIDO').AsFloat         := (FormatFloat('###,###,##0.00', fValor_Pedido)).ToDouble();
        qryExportar.ParamByName('ID_PEDIDO_MOBILE').AsInteger   := iId_Pedido_Mobile;

        qryExportar.ExecSQL;

        iID_PedidoGerado := fdConn.GetLastAutoGenValue('ID');

        (*
        //Inclusão dos itens do pedido
        jItens   := (jPedido as TJSONArray).Items[I].GetValue<TJSONArray>('itens');
        arrItens := (jItens as TJSONArray).Count;

        qryExportar.Active := False;
        qryExportar.SQL.Clear;
        qryExportar.SQL.Text         := INS_ITENS_PEDIDO;
        qryExportar.Params.ArraySize := arrItens;

        for J := 0 to Pred((jItens as TJSONArray).Count) do
        begin
          iQtde           := (jItens as TJSONArray).Items[J].GetValue<integer>('qtde');
          fValor_Unitario := (FormatFloat('###,###,##0.00', (jItens as TJSONArray).Items[J].GetValue<double>('valor_unitario'))).ToDouble();
          iId_Cardapio    := (jItens as TJSONArray).Items[J].GetValue<integer>('id_cardapio');

          qryExportar.ParamByName('ID_PEDIDO').AsIntegers[J]        := iID_PedidoGerado;
          qryExportar.ParamByName('QTDE').AsIntegers[J]             := iQtde;
          qryExportar.ParamByName('VALOR_UNITARIO').AsFloats[J]     := fValor_Unitario;
          qryExportar.ParamByName('ID_CARDAPIO').AsIntegers[J]      := iId_Cardapio;
          qryExportar.ParamByName('ID_PEDIDO_MOBILE').AsIntegers[J] := iId_Pedido_Mobile;
        end;

        qryExportar.Execute(arrItens, 0);
        *)
      end;
    end;

    if fdConn.InTransaction then
      fdConn.CommitRetaining;

    fdConn.TxOptions.AutoCommit := True;

    lJOBJ := TJSONObject.Create;
    lJOBJ.AddPair('Mensagem', 'Pedido enviado com sucesso!');

    Result := TJSONArray.Create;
    Result.AddElement(lJOBJ);

    GetInvocationMetaData().ResponseCode := 201;

    FormatarJSON(GetInvocationMetadata().ResponseCode, Result.ToJSON());
  except on E:Exception do
    begin
      fdConn.Rollback;
      raise;
    end;
  end;
end;

end.

