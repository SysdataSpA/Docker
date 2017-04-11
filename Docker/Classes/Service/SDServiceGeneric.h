//
//  ServiceGeneric.h
//  YooxNative
//
//  Created by Francesco Ceravolo on 26/06/14.
//  Copyright (c) 2014 Yoox Group. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>

/**
 *  Metodi HTTP supportati dal SDServiceManager.
 */
typedef NS_ENUM (NSUInteger, SDHTTPMethod)
{
    /**
     *  Rappresenta il metodo HTTP GET.
     */
    SDHTTPMethodGET = 0,
    /**
     *  Rappresenta il metodo HTTP POST.
     */
    SDHTTPMethodPOST,
    /**
     *  Rappresenta il metodo HTTP PUT.
     */
    SDHTTPMethodPUT,
    /**
     *  Rappresenta il metodo HTTP DELETE.
     */
    SDHTTPMethodDELETE,
    /**
     *  Rappresenta il metodo HTTP HEAD.
     */
    SDHTTPMethodHEAD,
    /**
     *  Rappresenta il metodo HTTP PATCH.
     */
    SDHTTPMethodPATCH
};

@interface MultipartBodyInfo : NSObject

@property (nonatomic, strong) NSData* data;
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSString* fileName;
@property (nonatomic, strong) NSString* mimeType;

@end


/**
 *  Protocollo implementato da tutte le requests.
 */
@protocol SDServiceGenericRequestProtocol <NSObject>
@optional
/**
 *  Gli headers da aggiungere o da modificare rispetto al default per la singola request.
 */
@property (nonatomic, strong) NSDictionary* additionalRequestHeaders;
/**
 *  I parametri aggiuntivi da passare rispetto a quelli definiti attraverso il mapping dell'oggetto di request.
 */
@property (nonatomic, strong) NSDictionary* additionalRequestParameters;

/**
 *  Impostazione per la rimozione dalla request dei parametri non valorizzati (il cui valore è nil)
 */
@property (nonatomic, assign) BOOL removeNilParameters;


/**
 *  Informazioni relative agli NSData da inviare in multipart nel servizio
 */
@property (nonatomic, strong) NSArray<MultipartBodyInfo*>* multipartInfos;

@end

/**
 *  Protocollo implementato da tutte le response.
 */
@protocol SDServiceGenericResponseProtocol <NSObject>
@required
/**
 *  Lo status code HTTP restituito dal servizio.
 */
@property (nonatomic, assign) int httpStatusCode;

/**
 *  Tutti gli header associati alla response
 */
@property (nonatomic, strong) NSDictionary* headers;

/**
 *  Nome della property in cui mappare il body della response nel caso in cui questo sia un array e non un dictionary.
 */
@property (readonly, nonatomic, strong) NSString* propertyNameForArrayResponse;

/**
 *  Classe degli oggetti contenuti nel body della response nel caso in cui questo sia un array e non un dictionary.
 */
@property (readonly, nonatomic, assign) Class classOfItemsInArrayResponse;
@end



/**
 *  Protocollo implementato da tutte gli error dei servizi.
 */
@protocol SDServiceGenericErrorProtocol <NSObject>
@required
/**
 *  Lo status code HTTP restituito dal servizio.
 */
@property (nonatomic, assign) int httpStatusCode;
/**
 *  L'oggetto NSError restituito dal SDServiceManager in caso di errore nel servizio.
 */
@property (nonatomic, strong) NSError* error;
@end

/**
 *  Protocollo implementato da tutti i SDServiceGeneric.
 */
@protocol SDServiceGenericProtocol <NSObject>
@required
/**
 *  Path del servizio che verrà aggiunto alla base url definita nel SDServiceManager.
 *
 *  @return il path del servizio relativo alla base url.
 */
- (NSString*) pathResource;

/**
 *  L'operation manager da utilizzare per il servizio. Di default viene utilizzato l'operation manager instanziato da SDServiceManager.
 *
 *  @discussion Tipicamente si restituisce nil per utilizzare quello di default. Restituire uno specifica istanza di AFHTTPRequestOperationManager per gestire i servizi su code separate.
 *
 *  @return L'operation manager da utilizzare per il servizio. Restituire nil per utilizzare l'operation manager di default.
 */
- (AFHTTPRequestOperationManager*) requestOperationManager;

/**
 *  Restituisce il metodo HTTP da utilizzare per la chiamata al servizio. Vedi SDHTTPMethod per maggiori dettagli. Di default restituisce SDHTTPMethodGET.
 *
 *  @return il metodo HTTP.
 */
- (SDHTTPMethod) requestMethodType;

/**
 *  Restituisce il dictionary che rappresenta i parametri da utilizzare in query string o nel body della request (a seconda del metodo HTTP del servizio).
 *
 *  @param request La request di cui si vuole il dictionary dei parametri.
 *  @param error      Eventuale errore di mapping passato per riferimento.
 *
 *  @return il dictionary dei parametri. In caso di errore, l'oggetto error viene valorizzato.
 */
- (NSDictionary*) parametersForRequest:(id<SDServiceGenericRequestProtocol>)request error:(NSError**)error;

/**
 *  Restituisce la response del servizio a partire dal NSDictionary di risposta o nil se l'oggetto del servizio non può essere mappato.
 *
 *  @param object     L'oggetto che arriva dal servizio da mappare nell'oggetto di response.
 *  @param error      Eventuale errore di mapping passato per riferimento.
 *
 *  @return L'oggetto di response o nil in caso di errore. In caso di errore, l'oggetto error viene valorizzato.
 */
- (id<SDServiceGenericResponseProtocol>) responseForObject:(id)object error:(NSError**)error;

/**
 *  Restituisce la response di errore del servizio a partire dal NSDictionary di risposta o nil se l'oggetto del servizio non può essere mappato.
 *
 *  @param object     L'oggetto che arriva dal servizio da mappare nell'oggetto di errore.
 *  @param error      Eventuale errore di mapping passato per riferimento.
 *
 *  @return L'oggetto di errore o nil in caso di errore. In caso di errore, l'oggetto error viene valorizzato.
 */
- (id<SDServiceGenericErrorProtocol>) errorForObject:(id)object error:(NSError**)error;

/**
 *  La classe dell'oggetto che rappresenta la response del servizio.
 *
 *  @return La classe della response.
 */
- (Class) responseClass;

/**
 *  La classe dell'oggetto che rappresenta l'errore del servizio.
 *
 *  @return La classe dell'errore.
 */
- (Class) errorClass;

@optional
/**
 *  Flag che indica se il servizio deve recuperare la risposta da un file in locale.
 *
 *  @return YES se il servizio deve recuperare la response da locale. NO se il servizio deve effettuare la chiamata al server. Di default è NO.
 */
- (BOOL) useDemoMode;

/**
 *  Nome del file in locale dal quale recuperare la risposta al servizio quando lo si usa in modalità demo.
 *
 *  @return Nome del file in locale.
 */
- (NSString*) demoModeJsonFileName;

/**
 *  Range entro il quale viene calcolato un valore random che rappresenta il tempo di attesa del servizio in demo mode.
 *
 *  @return rnage per il tempo di attesa
 */
- (NSRange) demoWaitingTimeRange;

@end

/**
 *  Classe di base da sottoclassare per definire i servizi specifici. Questa implementazione non fa alcun mapping delle requests e delle responses. Tipicamente si dovrà sottoclassare una implementazione più specifica di SDServiceGeneric, come SDServiceMantle.
 */
@interface SDServiceGeneric : NSObject <SDServiceGenericProtocol>
/**
 *  Flag che specifica se il servizio può essere ripetuto in caso di errore.
 */
@property (nonatomic, readonly) BOOL isRepeatable;
/**
 *  Recupera la response da un file locale. Il nome di default del file locale è il nome della classe del servizio, ma può essere sovrascritto mediante il metodo -(NSString*)demoModeJsonFileName.
 *
 *  @return La response recuperata da file locale o nil se non riesce a recuperarla.
 */
- (void) getResultFromJSONFileWithCompletion:(void (^) (id result))completion;

@end