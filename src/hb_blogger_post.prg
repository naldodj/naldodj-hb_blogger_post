/* Keeping it tidy */
#pragma -w3
#pragma -es2

/* Optimizations */
#pragma -km+
#pragma -ko+

#require "hbssl"
#require "hbtip"

REQUEST HB_CODEPAGE_UTF8EX

#if !defined(__HBSCRIPT__HBSHELL)
    REQUEST __HBEXTERN__HBSSL__
#endif

#include "tip.ch"
#include "hbver.ch"
#include "inkey.ch"
#include "fileio.ch"
#include "hbclass.ch"
#include "hbcompat.ch"

#define SW_HIDE             0
#define SW_SHOWNORMAL       1
#define SW_NORMAL           1
#define SW_SHOWMINIMIZED    2
#define SW_SHOWMAXIMIZED    3
#define SW_MAXIMIZE         3
#define SW_SHOWNOACTIVATE   4
#define SW_SHOW             5
#define SW_MINIMIZE         6
#define SW_SHOWMINNOACTIVE  7
#define SW_SHOWNA           8
#define SW_RESTORE          9

static s_cEOL as character

// Defina suas credenciais e chaves (substitua pelos seus valores)
static s_cNewsApiKey as character // API key para o serviço de notícias
static s_cBloggerID as character // ID do seu blog no Blogger
static s_cBloggerAccessToken as character // Blogger API Key

// Variáveis globais para OAuth2
static s_cScope as character
static s_cAuthURL as character
static s_cTokenURL as character
static s_cClientID as character

static s_cClientSecret as character
static s_cRedirectURI as character

static s_hIni as hash

//Variaveis para UHttpdNew
MEMVAR server,get,post,cookie,session

//---------------------------------------------------------------------
// Função: Main()
// Executa o fluxo: busca notícias -> gera Markdown -> converte para HTML -> publica no Blogger
//---------------------------------------------------------------------
procedure Main(...)

    local aArgs as array:=hb_AParams()

    local cTo as character
    local cFrom as character
    local cHtml as character
    local cParam as character
    local cTitle as character
    local cArgName as character
    local cMarkdown as character
    local cNewsJSON as character

    local lSuccess as logical:=.F.
    local lSanitizedata as logical

    local idx as numeric

    #ifdef __ALT_D__    // Compile with -b
        AltD(1)         // Enables the debugger. Press F5 to go.
        AltD()          // Invokes the debugger
    #endif

    s_cEOL:=hb_eol()

    hb_setCodePage("UTF8")
    hb_cdpSelect("UTF8EX")

    SET DATE ANSI
    SET CENTURY ON

    if (!Empty(aArgs))
        cParam:=Lower(aArgs[1])
        if (;
            cParam=="-h";
            .or.;
            cParam=="--help";
        )
            ShowHelp(nil,aArgs)
            return
        endif
        for each cParam in aArgs
            if (!Empty(cParam))
                if ((idx:=At("=",cParam))==0)
                    cArgName:=Lower(cParam)
                    cParam:=""
                else
                    cArgName:=Left(cParam,idx-1)
                    cParam:=SubStr(cParam,idx+1)
                endif
                do case
                case (cArgName=="-sanitize")
                    if (!Empty(cParam))
                        lSanitizeData:=(Left(cParam,1)$"Tt")
                    else
                        lSanitizeData:=.T.
                    endif
                case (cArgName=="-from")
                    cFrom:=cParam
                case (cArgName=="-to")
                    cTo:=cParam
                otherwise
                   ShowHelp("Unrecognized option:"+cArgName+iif(Len(cParam)>0,"="+cParam,""))
                   return
                endcase
            endif
        next each
    endif

    hb_Default(@lSanitizeData,.F.)
    hb_Default(@cFrom,hb_DToC(Date(),"yyyy-mm-dd"))
    hb_Default(@cTo,hb_DToC(Date(),"yyyy-mm-dd"))

    s_hIni:=ParseIni()

    begin sequence

        s_cNewsApiKey:=GetEnv("NEWS_API_KEY") // API key para o serviço de notícias
        // 1. Buscar notícias de tecnologia
        cNewsJSON:=GetNews(lSanitizeData,cFrom,cTo)

        // 2. Processar JSON e gerar Markdown
        cMarkdown:=JSONToMarkdown(cNewsJSON)

        // 3. Converter Markdown para HTML (Blogger requer HTML)
        if (!Empty(cMarkdown))
            cHtml:=ConvertMarkdownToHtml(cMarkdown)
            // 4. Publicar o post no Blogger
            cTitle:="BlackTDN NEWS :: "+DToC(Date())+" :: "+Time()
            lSuccess:=PublishToBlogger(cTitle,cHtml)
        endif

        if (lSuccess)
          ? "Post publicado com sucesso!"
        else
          ? "Falha ao publicar o post."
        endif

    end sequence

    return

//----------------------------------------------------------------------------//
static function ParseIni(lDefaultOnly as logical)

    local cKey as character
    local cVal as character
    local cSection as character
    local cIniFile as character

    local hIni as hash
    local hSect as hash
    local hDefault as hash

    local nPos as numeric

    local xVal as anytype

    hb_default(@lDefaultOnly,.F.)

    // Define here what attributes we can have in ini config file and their defaults
    // Please add all keys in uppercase. hDefaults is case Insensitive
    hDefault:={;
         "MAIN" => {;
            "SELECTED_AI" => "QWEN";
         };
        ,"NEWSAPI" => {;
             "URL" => "https://newsapi.org";
            ,"PATH" => "/v2/everything/";
            ,"QUERY" => "tecnologia";
            ,"SORTBY" => "popularity";
            ,"LANGUAGE" => "pt";
        };
        ,"HTTPSERVER" => {;
             "URL" => "http://127.0.0.1";
            ,"PORT" => 8002;
            ,"MAINPAGE" => ".\tpl\hb_blogger_post.html";
        };
        ,"QWEN" => {;
             "URL" => "https://api.qwen.com";
            ,"PATH" => "/v1/chat/completions";
            ,"MODEL" => "qwen-7b";
        };
        ,"DEEPSEEK" => {;
             "URL" => "https://api.deepseek.com";
            ,"PATH" => "/chat/completions";
            ,"URLBALANCE" => "https://api.deepseek.com";
            ,"PATHBALANCE" => "/user/balance";
            ,"MODEL" => "deepseek-r1";
        };
        ,"LMSTUDIO" => {;
             "URL" => "http://127.0.0.1";
            ,"PORT" => 1234;
            ,"PATH" => "/v1/chat/completions";
            ,"MODEL_QWEN" => "LMSTUDIO_QWEN";
            ,"MODEL_DEEPSEEK" => "LMSTUDIO_DEEPSEEK";
        };
        ,"LMSTUDIO_QWEN" => {;
             "PATH" => "/v1/chat/completions";
            ,"MODEL" => "qwen2.5-7b-instruct-1m";
        };
        ,"LMSTUDIO_DEEPSEEK" => {;
             "PATH" => "/v1/chat/completions";
            ,"MODEL" => "deepseek-r1-distill-qwen-7b";
        };
    }

    hb_HCaseMatch(hDefault,.F.)

    if (!lDefaultOnly)

        cIniFile:=hb_FNameExtSet(ExeName(),".ini")
        if (hb_FileExists(cIniFile))
            hIni:=hb_iniRead(cIniFile,.T.)// .T. = load all keys in MixedCase,redundant as it is default,but to remember
        endif

        // Now read changes from ini file and modify only admited keys
        if (!Empty(hIni))
            for each cSection in hIni:Keys
                cSection:=Upper(cSection)
                if (cSection$hDefault)
                    hSect:=hIni[cSection]
                    if (HB_ISHASH(hSect))
                        for each cKey in hSect:Keys
                            // Please,below check values MUST be uppercase
                            if ((cKey:=Upper(cKey))$hDefault[cSection]) // force cKey to be uppercase
                                if ((nPos:=hb_HScan(hSect,{|k|Upper(k)==cKey}))>0)
                                    cVal:=hb_HValueAt(hSect,nPos)
                                    switch cSection
                                    case "HTTPSERVER"
                                        if (cKey=="PORT")
                                            xVal:=Val(cVal)
                                        else
                                            xVal:=cVal
                                        endif
                                        exit
                                    case "LMSTUDIO"
                                        if (cKey=="PORT")
                                            xVal:=Val(cVal)
                                        else
                                            xVal:=cVal
                                        endif
                                        exit
                                    otherwise
                                        xVal:=cVal
                                    end switch
                                    if (xVal!=NIL)
                                        hDefault[cSection][cKey]:=xVal
                                    endif
                                endif
                            endif
                        next cKey
                    endif
                endif
            next cSection
        endif
    endif

   return(hDefault)

//---------------------------------------------------------------------
// Função: GetNews()
// Usa TIPClientHTTP para efetuar uma requisição GET à API de notícias.
//---------------------------------------------------------------------
static function GetNews(lSanitizedata as logical,cFrom as character,cTo as character)

    local aNewsTech as array

    local cURL as character
    local cPrompt as character
    local cResponse as character
    local cResponseNew as character
    local cJSONArticle as character
    local cReponseUserBalance as character

    local hNews,hArticle as hash
    local hReponseUserBalance as hash

    local lNewsTech as logical

    local nArticle as numeric

    local oURL as object
    local oHTTP as object
    local oTApiAI as object

    cURL:=s_hIni["NEWSAPI"]["URL"]
    cURL+=s_hIni["NEWSAPI"]["PATH"]

    //FixMe!
    cURL:=strTran(cURL,"https","http")

    // Cria objeto TUrl (construtor definido na TIP – ver tipwget.prg)
    oURL:=TUrl():New(cURL)
    oHTTP:=TIPClientHTTP():New(oURL)
    oHTTP:hFields["Content-Type"]:="application/JSON"
    oHTTP:hFields["X-Api-Key"]:=s_cNewsApiKey

    /* build the search query and add it to the TUrl object */
    oHTTP:oURL:addGetForm(;
        {;
            "q" => s_hIni["NEWSAPI"]["QUERY"];
           ,"sortBy" => s_hIni["NEWSAPI"]["SORTBY"];
           ,"language" => s_hIni["NEWSAPI"]["LANGUAGE"];
           ,"from" => cFrom;
           ,"to" => cTo;
           ,"apiKey" => s_cNewsApiKey;
        };
    )

    /* Connect to the HTTP server */
    oHTTP:nConnTimeout:=15000

    ? "Connecting to",oURL:cProto+"://"+oURL:cServer+oURL:cPath+"?"+oURL:cQuery

    if (oHTTP:Open())
        ? "Connection status:",iif(Empty(oHTTP:cReply),"<connected>",oHTTP:cReply)
        /* download the response */
        cResponse:=oHTTP:ReadAll()
        if (Empty(cResponse))
            ? oHTTP:LastErrorMessage(oHTTP:SocketCon)
        endif
        oHTTP:Close()
    else
         ? oHTTP:LastErrorMessage(oHTTP:SocketCon)
    endif

    hb_default(@cResponse,"")

    if ((lSanitizeData).and.!Empty(cResponse))
        hb_JSONDecode(cResponse,@hNews)
        begin sequence
            oTApiAI:=TApiAI():New()
            if ((valType(hNews)!="H").or.(!hb_HHasKey(hNews,"status")))
                break
            endif
            if (hNews["status"]!="ok")
                break
            endif
            if (hb_HHasKey(hNews,"totalResults"))
                if (hNews["totalResults"]==0)
                    break
                endif
            endif
            if (!hb_HHasKey(hNews,"articles"))
                break
            endif
            switch s_hIni["MAIN"]["SELECTED_AI"]
            case "DEEPSEEK"
                cReponseUserBalance:=oTApiAI:GetUserBalance()
                hb_JSONDecode(cReponseUserBalance,@hReponseUserBalance)
                if (!((valType(hReponseUserBalance)=="H").and.(hb_HHasKey(hReponseUserBalance,"is_available")).and.(hReponseUserBalance["is_available"])))
                    oTApiAI:cUrl:=s_hIni["LMSTUDIO"]["URL"]
                    oTApiAI:cUrl+=":"
                    oTApiAI:cUrl+=hb_NToC(s_hIni["LMSTUDIO"]["PORT"])
                    oTApiAI:cUrl+=s_hIni[s_hIni["LMSTUDIO"]["MODEL_DEEPSEEK"]]["PATH"]
                    oTApiAI:cModel:=s_hIni[s_hIni["LMSTUDIO"]["MODEL_DEEPSEEK"]]["MODEL"]
                endif
                exit
            case "QWEN"
                if ((Empty(oTApiAI:cKey)).and.(empty(GetEnv("QWEN_API_KEY"))))
                    oTApiAI:cUrl:=s_hIni["LMSTUDIO"]["URL"]
                    oTApiAI:cUrl+=":"
                    oTApiAI:cUrl+=hb_NToC(s_hIni["LMSTUDIO"]["PORT"])
                    oTApiAI:cUrl+=s_hIni[s_hIni["LMSTUDIO"]["MODEL_QWEN"]]["PATH"]
                    oTApiAI:cModel:=s_hIni[s_hIni["LMSTUDIO"]["MODEL_QWEN"]]["MODEL"]
                endif
                exit
            otherwise
                break
            end switch
            aNewsTech:=Array(0)
            for each hArticle in hNews["articles"]
                nArticle:=hArticle:__enumIndex()
                hb_HSet(hArticle,"sourceIndex",nArticle)
                #pragma __cstream|cPrompt:=%s
Given individual JSON objects representing news articles in Portuguese,determine if each article is related to technology. Use the title, or description, to identify technology-related content,such as topics on computing,software,devices,or modern technologies. For each article,respond only with true if it is related to technology or false if it is not. Maintain the same evaluation criteria for all responses.:
                #pragma __endtext
                cJSONArticle:=hb_JSONEncode({"title"=>hArticle["title"],"description"=>hArticle["description"]})
                cPrompt+=" ```json"+s_cEOL+cJSONArticle+s_cEOL+"```"
                oTApiAI:Send(cPrompt)
                cResponseNew:=oTApiAI:GetValue()
                lNewsTech:=("true"==Right(cResponseNew,4))
                if (lNewsTech)
                    aAdd(aNewsTech,hArticle)
                endif
            end each
            lNewsTech:=(!Empty(aNewsTech))
            if (lNewsTech)
                hNews["totalResults"]:=Len(aNewsTech)
                hNews["articles"]:=aNewsTech
            endif
        end sequence
        oTApiAI:End()
        hb_default(@lNewsTech,.F.)
        if (lNewsTech)
            cResponse:=hb_JSONEncode(hNews)
        endif
    endif

    return(cResponse) as character

//---------------------------------------------------------------------
// Função: JSONToMarkdown(cJSON)
// Gera um texto em Markdown formatado com título,descrição e link para cada notícia.
//---------------------------------------------------------------------
static function JSONToMarkdown(cJSON as character)

    local aArticles as array

    local cMarkdown as character:=""

    local hJSON as hash
    local hArticle as hash

    local i as numeric

    begin sequence

        hb_MemoWrit("JSONToMarkdownNews.JSON",cJSON)

        if (empty(cJSON))
            break
        endif

        hb_JSONDecode(cJSON,@hJSON)

        if ((valType(hJSON)!="H").or.(!hb_HHasKey(hJSON,"status")))
            break
        endif

        if (hJSON["status"]!="ok")
            break
        endif

        if (hb_HHasKey(hJSON,"totalResults"))
            if (hJSON["totalResults"]==0)
                break
            endif
        endif

        if (!hb_HHasKey(hJSON,"articles"))
            break
        endif

        aArticles:=hJSON["articles"]

        for i:=1 to Len(aArticles)

            hArticle:=aArticles[i]

            // Título da notícia
            cMarkdown+="# "+if(!Empty(hArticle["title"]),hArticle["title"],hArticle["description"])+s_cEOL

            // Fonte e autor
            cMarkdown+="**Fonte:** "+hArticle["source"]["name"]+s_cEOL
            if (!Empty(hArticle["author"]))
                cMarkdown+="**Autor:** "+hArticle["author"]+s_cEOL
            endif

            // data de publicação
            cMarkdown+="**Publicado em:** "+hArticle["publishedAt"]+s_cEOL+s_cEOL

            // Imagem (se disponível)
            if (!Empty(hArticle["urlToImage"]))
                cMarkdown+="![Imagem]("+hArticle["urlToImage"]+")"+s_cEOL+s_cEOL
            endif

            // Descrição (citação)
            if (!Empty(hArticle["description"]))
                cMarkdown+="> "+hArticle["description"]+s_cEOL+s_cEOL
            endif

            // Link para a notícia completa
            cMarkdown+="[Leia mais]("+hArticle["url"]+")"+s_cEOL+s_cEOL

            // Separador entre notícias
            cMarkdown+="---"+s_cEOL+s_cEOL

        next i

    end sequence

    return(cMarkdown) as character

//---------------------------------------------------------------------
// Função: ConvertMarkdownToHtml(cMarkdown)
//---------------------------------------------------------------------
static function ConvertMarkdownToHtml(cMarkdown as character)
   local cNewMarkDown as character
#pragma __cstream|cNewMarkDown:=%s
<div class="separator" style="clear: both;"><a href="https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgKfeXkOvdidB4y-2xSljMmUFRf1l432sFeW5_1prYw2SnGtOvI2HtkDBm-aRNHt5wUGkjcEGtVrWYKGegXsmoX84C1C6V-aWJoj0jY49MwAiR6Jxecyzp1Sfgj9-V64KUCAQ2bTt3kFHEP5px2eoWeXwV5-nZ6YvXd8nEfMmaK-c4Mo0JAgqCDg33Kxo8/s1792/blacktdn_new_banner.webp" style="display: block; padding: 1em 0; text-align: center; "><img alt="" border="0" width="400" data-original-height="1024" data-original-width="1792" src="https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgKfeXkOvdidB4y-2xSljMmUFRf1l432sFeW5_1prYw2SnGtOvI2HtkDBm-aRNHt5wUGkjcEGtVrWYKGegXsmoX84C1C6V-aWJoj0jY49MwAiR6Jxecyzp1Sfgj9-V64KUCAQ2bTt3kFHEP5px2eoWeXwV5-nZ6YvXd8nEfMmaK-c4Mo0JAgqCDg33Kxo8/s400/blacktdn_new_banner.webp"/></a></div>
#pragma __endtext
   cNewMarkDown+=s_cEOL
   cNewMarkDown+='<pre class="markdown">_Créditos das imagens: ChatGPT'+s_cEOL+cMarkdown+s_cEOL+'</pre>'
   return(cNewMarkDown) as character

//---------------------------------------------------------------------
// Função: PublishToBlogger(cTitle,cContent)
// Publica o post no Blogger via API REST usando TIPClientHTTP.
//---------------------------------------------------------------------
static function PublishToBlogger(cTitle as character,cContent as character)

    local cURL as character
    local cJSONdata as character
    local cResponse as character
    local cAccessToken  as character

    local hJSONdata as hash

    local oURL as object
    local oHTTP as object

    s_cBloggerID:=GetEnv("BLOGGER_ID") // ID do seu blog no Blogger
    s_cBloggerAccessToken:=GetEnv("BLOGGER_API_KEY") // Blogger API Key

    // Variáveis globais para OAuth2
    s_cClientID:=GetEnv("GOOGLE_CLIENT_ID")
    s_cClientSecret:=GetEnv("GOOGLE_CLIENT_SECRET")
    s_cRedirectURI:="http://localhost:"+hb_NToC(s_hIni["HTTPSERVER"]["PORT"])+"/oauth2callback"
    s_cAuthURL:="https://accounts.google.com/o/oauth2/v2/auth"
    s_cTokenURL:="https://accounts.google.com/o/oauth2/token"
    s_cScope:="https://www.googleapis.com/auth/blogger"

    cAccessToken:=GetOAuth2Token() // Obter token via OAuth2

    if (!Empty(cAccessToken))

        // Constrói a URL do endpoint de inserção de posts do Blogger
        //https://developers.google.com/blogger/docs/3.0/reference/posts?hl=pt-br#resource
        cURL:="https://www.googleapis.com/blogger/v3/blogs/"+s_cBloggerID+"/posts?isDraft=true"

        // Prepara o corpo JSON da requisição conforme a documentação do Blogger API v3
        hJSONData:={;
                        "kind" => "blogger#post";
                       ,"blog" => {;
                            "id" => s_cBloggerID;
                        };
                       ,"title" => cTitle;
                       ,"content" => cContent;
                       ,"labels" => "#BlackTDN NEWS";
        }

        // Cria o objeto TIPClientHTTP para a URL do Blogger
        oURL:=TUrl():New(cURL)
        oHTTP:=TIPClientHTTP():New(oURL)

        // Define os cabeçalhos adicionais (em hFields – conforme a implementação TIP)
        oHTTP:hFields["Authorization"]:="Bearer "+cAccessToken
        oHTTP:hFields["Content-Type"]:="application/JSON"

        // Efetua a requisição POST com o corpo JSON
        cJSONData:=hb_JSONEncode(hJSONData)

        if (oHTTP:Open())
            if (oHTTP:Post(cJSONData))
                ? cResponse:=oHTTP:cReply
                ? hb_ValToExp(oHTTP:hHeaders)
            else
                ? "Error:","oHTTP:Post()",oHTTP:LastErrorMessage()
            endif
            oHTTP:Close()
        else
            ? "Error:","oHTTP:Open()",oHTTP:LastErrorMessage()
        endif

    endif

    return(!Empty(cResponse)) as logical

//---------------------------------------------------------------------
// Função: GetOAuth2Token()
// Obtém um token de acesso via OAuth2 (Authorization Code Flow)
//---------------------------------------------------------------------
static function GetOAuth2Token()

    local cAccessToken as character

    local lHTTPServer as logical

    local oLogError as object
    local oLogAccess as object

    local oTHtml as object
    local oTHtmlForm as object
    local oHTTPServer as object

    ? s_hIni["HTTPSERVER"]["URL"]+":"+hb_NToC(s_hIni["HTTPSERVER"]["PORT"])
    *hb_idleSleep(.1)

    oTHtml:=THtmlDocument():New(hb_MemoRead(s_hIni["HTTPSERVER"]["MAINPAGE"]))
    oTHtmlForm:=oTHtml:Body:Form
    oTHtmlForm:attr:="action='"+s_hIni["HTTPSERVER"]["URL"]+":"+hb_NToC(s_hIni["HTTPSERVER"]["PORT"])+"/auth'"
    oTHtml:WriteFile(s_hIni["HTTPSERVER"]["MAINPAGE"])

    ShellExecuteEx(NIL,"open",s_hIni["HTTPSERVER"]["MAINPAGE"],"",NIL,SW_SHOWNORMAL)

    oLogError:=UHttpdLog():New("hb_blogger_post_error.log")
    oLogAccess:=UHttpdLog():New("hb_blogger_post_access.log")

    if (hb_FileExists(".uhttpd.stop"))
        fErase(".uhttpd.stop")
    endif

    // Configurar rotas
    oHTTPServer:=UHttpdNew()
    lHTTPServer:=oHTTPServer:Run(;
        {;
             "FirewallFilter"   => "";
            ,"LogAccess"        => {| m | oLogAccess:Add(m+s_cEOL) };
            ,"LogError"         => {| m | oLogError:Add(m+s_cEOL) };
            ,"Trace"            => {| ... | QOut(...) };
            ,"Port"             => s_hIni["HTTPSERVER"]["PORT"];
            ,"Idle"             => {|o|iif(hb_FileExists(".uhttpd.stop"),(fErase(".uhttpd.stop"),o:Stop()),NIL)};
            ,"SSL"              => .F.;
            ,"Mount"            => {;
                 "/info"           => {||UProcInfo()};
                ,"/auth"           => @AuthHandler();// Inicia o fluxo OAuth2
                ,"/oauth2callback" => @CallbackHandler();// Recebe o código de autorização
                ,"/"               => {||URedirect("/auth")};
            };
        };
    )

    oLogError:Close()
    oLogAccess:Close()

    if (lHTTPServer)

        if (file("hb_blogger_post.token"))
            cAccessToken:=hb_MemoRead("hb_blogger_post.token")
            fErase("hb_blogger_post.token")
        else
            hb_default(@cAccessToken,"")
        endif

    else

        hb_default(@cAccessToken,"")

    endif

    return(cAccessToken)

static function AuthHandler()

    local cKey as character
    local cValue as character
    local cParams as character:=""

    local hkey as hash
    local hkeys as hash:={;
         "redirect_uri"   => s_cRedirectURI;
        ,"prompt"        => "consent";
        ,"response_type" => "code";
        ,"client_id"     => s_cClientID;
        ,"scope"         => s_cScope;
    }

    for each hkey in hkeys
        cKey:=hKey:__enumKey()
        cValue:=hKey:__enumValue()
        cParams+=tip_URLEncode(AllTrim(hb_CStr(cKey)))+"="+tip_URLEncode(AllTrim(cValue))
        if (!hkey:__enumIsLast())
            cParams+="&"
         endif
    next each

    if (Right(cParams,1)=="&")
        cParams:=SubStr(cParams,1,Len(cParams)-1)
    endif

    USessionStart()
    URedirect(s_cAuthURL+"?"+cParams) // Redireciona o navegador

    return(.T.)

static function CallbackHandler()

    local cAuthCode as character
    local cAccessToken as character

    if (hb_HHasKey(get,"code"))
        cAuthCode:=get["code"]
        cAccessToken:=ExchangeCodeForToken(cAuthCode)
        hb_MemoWrit("hb_blogger_post.token",cAccessToken)
   endif

   hb_MemoWrit(".uhttpd.stop","")

    return({"AccessToken"=>cAccessToken})

static function ExchangeCodeForToken(cAuthCode as character)

    local cAccessToken as character
    local cTokenResponse as character

    local hkeys as hash
    local hJSONResponse as hash

    local oURL as object
    local oHTTP as object

    // 2. Trocar código por token de acesso
    hkeys:={;
        "code"          => cAuthCode,;
        "redirect_uri"  => s_cRedirectURI,;
        "client_id"     => s_cClientID,;
        "client_secret" => s_cClientSecret,;
        "grant_type"    => "authorization_code";
    }

    // Cria o objeto TIPClientHTTP para a URL do Blogger
    oURL:=TUrl():New(s_cTokenURL)
    oHTTP:=TIPClientHTTP():New(oURL)
    oHTTP:hFields["Content-Type"]:="application/x-www-form-urlencoded"

    if (oHTTP:Open())
        if (oHTTP:Post(hkeys))
            cTokenResponse:=oHTTP:ReadAll()
            QOut("cTokenResponse",cTokenResponse)
            hb_JSONDecode(cTokenResponse,@hJSONResponse)
            if (hb_HHasKey(hJSONResponse,"access_token"))
                cAccessToken:=hJSONResponse["access_token"]
                QOut("cAccessToken",cAccessToken)
                hb_MemoWrit("hb_blogger_post.token",cAccessToken)
            endif
            QOut(hb_ValToExp(oHTTP:hHeaders))
        else
            QOut("Error:","oHTTP:Post()",oHTTP:LastErrorMessage())
        endif
        oHTTP:Close()
    else
        QOut("Error:","oHTTP:Open()",oHTTP:LastErrorMessage())
    endif

    return(cAccessToken)

// Based on https://api-docs.deepseek.com
// Remember to register in https://deepseek.com/ and get your API key
// class TApiAI for Harbour
//----------------------------------------------------------------------------//
class TApiAI

    data cUrl as character init ""
    data cKey as character init ""
    data cModel as character init ""
    data cApiAI as character init ""
    data cResponse as character init ""

    data phCurl as pointer

    data nError as numeric init 0
    data nHttpCode as numeric init 0

    method New(cApiAI as character,cKey as character,cModel as character)
    method Send(cPrompt as character)
    method End()
    method GetValue(cHKey as character)
    
    //DeepSeek Only
    method GetUserBalance()

endclass
//----------------------------------------------------------------------------//
method New(cApiAI as character,cKey as character,cModel as character) class TApiAI
    
    local cSELECTED_AI as character
    
    ::phCurl:=curl_easy_init()
    
    cSELECTED_AI:=s_hIni["MAIN"]["SELECTED_AI"]
    hb_default(@cApiAI,cSELECTED_AI)

    switch cSELECTED_AI
    case "DEEPSEEK"
        hb_default(@cKey,GetEnv("DEEPSEEK_API_KEY"))
        hb_default(@cModel,s_hIni["DEEPSEEK"]["MODEL"])
        ::cUrl:=s_hIni["DEEPSEEK"]["URL"]
        ::cUrl+=s_hIni["DEEPSEEK"]["PATH"]
        exit
    case "QWEN"
        hb_default(@cKey,GetEnv("QWEN_API_KEY"))
        hb_default(@cModel,s_hIni["QWEN"]["MODEL"])
        ::cUrl:=s_hIni["QWEN"]["URL"]
        ::cUrl+=s_hIni["QWEN"]["PATH"]
        exit
    end switch

    if (!Empty(cApiAI))
        ::cApiAI:=cApiAI
    endif
    
    if (!Empty(cKey))
        ::cKey:=cKey
    endif
    
    if (!Empty(cModel))
        ::cModel:=cModel
    endif

    return(self)
//----------------------------------------------------------------------------//
method End() class TApiAI
    curl_easy_cleanup(::phCurl)
    return(nil)
//----------------------------------------------------------------------------//
method GetValue(cHKey as character) class TApiAI
    local aKeys as array:=hb_AParams()
    local cKey as character
    local uValue:=hb_JSONDecode(::cResponse)
    hb_default(@cHKey,"content")
    if (cHKey=="content")
        TRY
            uValue:=uValue["choices"][1]["message"]["content"]
        CATCH
            TRY
                uValue:=uValue["error"]["message"]
            CATCH
                uValue:=uValue
            END
        END
    endif
    TRY
        for each cKey in aKeys
            if (ValType(uValue[cKey])=="A")
                uValue:=uValue[cKey][1]["choices"][1]["message"]["content"]
            else
                uValue:=uValue[cKey]
            endif
        next
    CATCH
        //...
    END
    return(uValue)
//----------------------------------------------------------------------------//
method Send(cPrompt as character) class TApiAI

    local aHeaders as array

    local cJSON as character

    local hRequest as hash:={ => }
    local hMessage1 as hash:={ => }
    local hMessage2 as hash:={ => }

    curl_easy_setopt(::phCurl,HB_CURLOPT_POST,.T.)
    curl_easy_setopt(::phCurl,HB_CURLOPT_URL,::cUrl)

    aHeaders:={ "Content-Type: application/JSON","Authorization: Bearer "+::cKey}

    curl_easy_setopt(::phCurl,HB_CURLOPT_HTTPHEADER,aHeaders)
    curl_easy_setopt(::phCurl,HB_CURLOPT_USERNAME,'')
    curl_easy_setopt(::phCurl,HB_CURLOPT_DL_BUFF_SETUP)
    curl_easy_setopt(::phCurl,HB_CURLOPT_SSL_VERIFYPEER,.F.)

    hRequest["model"]:=::cModel
    hRequest["temperature"]:=0.2
    //hRequest["stop"]:={"</think>"}

    hMessage1["role"]:="system"
    hMessage1["content"]:="You are a helpfull assistant."
    hMessage2["role"]:="user"
    hMessage2["content"]:=cPrompt
    hRequest["messages"]:={hMessage1,hMessage2}
    hRequest["stream"]:=.F.

    cJSON:=hb_JSONEncode(hRequest)
    curl_easy_setopt(::phCurl,HB_CURLOPT_POSTFIELDS,cJSON)

    ::nError:=curl_easy_perform(::phCurl)
    if (::nError==HB_CURLE_OK)
        curl_easy_getinfo(::phCurl,HB_CURLINFO_RESPONSE_CODE,@::nHttpCode)
        if (::nError==HB_CURLE_OK)
            ::cResponse:=curl_easy_dl_buff_get(::phCurl)
            if ("```json"$::cResponse)
                ::cResponse:=SubStr(::cResponse,AT("```json",::cResponse)+1)
                ::cResponse:=allTrim(SubStr(::cResponse,1,Len(::cResponse)-3))
            endif
        else
            ::cResponse:="Error code "+Str(::nError)
        endif
    else
        ::cResponse:="Error code "+Str(::nError)
    endif

    return(::cResponse)
//----------------------------------------------------------------------------//
method GetUserBalance() class TApiAI

    local aHeaders as array

    local cURL as character
    local cSELECTED_AI as character

    local phCurl as pointer

    cSELECTED_AI:=s_hIni["MAIN"]["SELECTED_AI"]
    
    if (cSELECTED_AI=="DEEPSEEK")
    
        aHeaders:={"Content-Type: application/JSON","Authorization: Bearer "+::cKey}

        cURL:=s_hIni["DEEPSEEK"]["URLBALANCE"]
        cURL+=s_hIni["DEEPSEEK"]["PATHBALANCE"]

        phCurl:=curl_easy_init()

        curl_easy_setopt(phCurl,HB_CURLOPT_URL,cURL)
        curl_easy_setopt(phCurl,HB_CURLOPT_HTTPHEADER,aHeaders)
        curl_easy_setopt(phCurl,HB_CURLOPT_USERNAME,'')

        //Disabling the SSL peer verification (you can use it if you have no SSL certificate yet,but still want to test HTTPS)
        curl_easy_setopt(phCurl,HB_CURLOPT_FOLLOWLOCATION,.T.)
        curl_easy_setopt(phCurl,HB_CURLOPT_SSL_VERIFYPEER,.F.)
        curl_easy_setopt(phCurl,HB_CURLOPT_SSL_VERIFYHOST,.F.)

        curl_easy_setopt(phCurl,HB_CURLOPT_NOPROGRESS,.F.)
        curl_easy_setopt(phCurl,HB_CURLOPT_VERBOSE,.T.)

        //Setting the buffer
        curl_easy_setopt(phCurl,HB_CURLOPT_DL_BUFF_SETUP)

        ::nError:=curl_easy_perform(phCurl)
        if (::nError==HB_CURLE_OK)
            curl_easy_getinfo(phCurl,HB_CURLINFO_RESPONSE_CODE,@::nHttpCode)
            if (::nError==HB_CURLE_OK)
                ::cResponse:=curl_easy_dl_buff_get(phCurl)
            else
                ::cResponse:="Error code "+Str(::nError)
            endif
        else
            ::cResponse:="Error code "+Str(::nError)
        endif

        curl_easy_cleanup(phCurl)
    
    else
        
        ::cResponse:=""
    
    endif

    return(::cResponse)

static procedure ShowSubHelp(xLine as anytype,/*@*/nMode as numeric,nIndent as numeric,n as numeric)

    local cKey as character
    local cVal as character
    local cSection as character

    local hSect as hash

    local nPos as numeric

    local xVal as anytype

    do case
    case xLine==NIL
    case HB_ISNUMERIC(xLine)
        nMode:=xLine
    case HB_ISEVALITEM(xLine)
        Eval(xLine)
    case HB_ISARRAY(xLine)
        if (nMode==2)
            OutStd(Space(nIndent)+Space(2))
        endif
        AEval(xLine,{| x,n | ShowSubHelp(x,@nMode,nIndent+2,n) })
        if (nMode==2)
            OutStd(s_cEOL)
        endif
    case HB_ISHASH(xLine)
        if (nMode==2)
            OutStd(Space(nIndent)+Space(2))
        endif
        for each cSection in xLine:Keys
            cSection:=Upper(cSection)
            ShowSubHelp("["+cSection+"]",@nMode,nIndent+2,n)
            hSect:=xLine[cSection]
            if (HB_ISHASH(hSect))
                for each cKey in hSect:Keys
                    cKey:=Upper(cKey)
                    if ((nPos:=hb_HScan(hSect,{|k|Upper(k)==cKey}))>0)
                        cVal:=hb_HValueAt(hSect,nPos)
                        xVal:=cVal
                        if (xVal!=NIL)
                            if (valType(xVal)=="N")
                                ShowSubHelp(cKey+"="+hb_NToC(xVal),@nMode,nIndent+4,n)
                            else
                                ShowSubHelp(cKey+"="+xVal,@nMode,nIndent+4,n)
                            endif
                        endif
                    endif
                next cKey
            endif
        next cSection
        if (nMode==2)
            OutStd(s_cEOL)
        endif
    otherwise
        switch nMode
            case 1
                OutStd(Space(nIndent)+xLine+s_cEOL)
                exit
            case 2
                OutStd(iif(n > 1,",","")+xLine)
                exit
            otherwise
                OutStd("("+hb_ntos(nMode)+") "+xLine+s_cEOL)
        end switch
    endcase

    return

static function HBRawVersion()
   return(;
       hb_StrFormat("%d.%d.%d%s (%s) (%s)";
      ,hb_Version(HB_VERSION_MAJOR);
      ,hb_Version(HB_VERSION_MINOR);
      ,hb_Version(HB_VERSION_RELEASE);
      ,hb_Version(HB_VERSION_STATUS);
      ,hb_Version(HB_VERSION_ID);
      ,"20"+Transform(hb_Version(HB_VERSION_REVISION),"99-99-99 99:99"));
   ) as character

static procedure ShowHelp(cExtraMessage as character,aArgs as array)

   local aHelp as array
   local nMode as numeric:=1

   if (Empty(aArgs).or.(Len(aArgs)<=1).or.(Empty(aArgs[1])))
      aHelp:={;
         cExtraMessage;
         ,"hb_blogger_post ("+ExeName()+") "+HBRawVersion();
         ,"Copyright (c) 2025-"+hb_NToS(Year(Date()))+","+hb_Version(HB_VERSION_URL_BASE);
         ,"";
         ,"Syntax:";
         ,"";
         ,{ExeName()+" [options]"};
         ,"";
         ,"Options:";
         ,{;
             "-h or --help    Show this help screen";
            ,"-sanitize       Filter the JSON,keeping only technology-related information";
            ,"-from=<date>    Specify the start date [yyyy-mm-dd]";
            ,"-to=<date>      Specify the end date [yyyy-mm-dd]";
         };
         ,"";
         ,"Ini Config Options:";
         ,{;
            ParseIni(.T.);
         };
         ,"";
      }
   else
      ShowHelp("Unrecognized help option")
      return
   endif

   /* using hbmk2 style */
   aEval(aHelp,{|x|ShowSubHelp(x,@nMode,0)})

   return

//----------------------------------------------------------------------------//
/*
 * C-level
*/
#pragma BEGINDUMP

    #include <shlobj.h>
    #include <windows.h>
    #include "hbapi.h"

    HB_FUNC_STATIC(SHELLEXECUTEEX)
    {
        SHELLEXECUTEINFO SHExecInfo;

        ZeroMemory(&SHExecInfo,sizeof(SHExecInfo));

        SHExecInfo.cbSize = sizeof(SHExecInfo);
        SHExecInfo.fMask = SEE_MASK_NOCLOSEPROCESS;
        SHExecInfo.hwnd  = HB_ISNIL(1) ? GetActiveWindow() : (HWND) hb_parnl(1);
        SHExecInfo.lpVerb = (LPCSTR) hb_parc(2);
        SHExecInfo.lpFile = (LPCSTR) hb_parc(3);
        SHExecInfo.lpParameters = (LPCSTR) hb_parc(4);
        SHExecInfo.lpDirectory = (LPCSTR) hb_parc(5);
        SHExecInfo.nShow = hb_parni(6);

        if(ShellExecuteEx(&SHExecInfo))
            hb_retptr(SHExecInfo.hProcess);  // Retorna um ponteiro corretamente
        else
            hb_retptr(NULL);                 // Retorna NULL se falhar
    }

#pragma ENDDUMP

//---------------------------------------------------------------------
// Fim do programa
//---------------------------------------------------------------------
