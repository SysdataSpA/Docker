//
//  SDServiceMantle.h
//  RestkitRemoval
//
//  Created by Paolo Ardia on 28/01/16.
//  Copyright © 2016 Francesco Ceravolo. All rights reserved.
//

#import "SDServiceGeneric.h"
#import <Mantle/Mantle.h>

/**
 *  Questa classe rappresenta il servizio di base da sottoclassare quando si usa Mantle per mappare la request e la response.
 *
 *  Il servizio specifico deve sempre sottoclassare SDServiceMantle per definire i dettagli specifici del servizio.
 */
@interface SDServiceMantle : SDServiceGeneric

@end

/**
 *  Questa classe rappresenta la request di base da sottoclassare quando si usa Mantle per mappare la request e la response.
 *
 *  La request del servizio specifico deve sottoclassare SDServiceMantleRequest se deve passare dei parametri in query string o nel body.
 *
 *  Per definire il mapping della request si deve reimplementare il metodo di MTLJSONSerializing +(NSDictionary*)JSONKeyPathsByPropertyKey.
 */
@interface SDServiceMantleRequest : MTLModel<MTLJSONSerializing, SDServiceGenericRequestProtocol>

@end

/**
 *  Questa classe rappresenta la response di base da sottoclassare quando si usa Mantle per mappare la request e la response.
 *
 *  La response del servizio specifico deve sottoclassare SDServiceMantleResponse se il servizio prevede un oggetto in risposta.
 *
 *  Per definire il mapping della response si deve reimplementare il metodo di MTLJSONSerializing +(NSDictionary*)JSONKeyPathsByPropertyKey.
 */
@interface SDServiceMantleResponse : MTLModel<MTLJSONSerializing, SDServiceGenericResponseProtocol>

@end

/**
 *  Questa classe rappresenta la response di base da sottoclassare quando si usa Mantle per mappare la request e la response.
 *
 *  La response in caso di errore del servizio specifico deve sottoclassare SDServiceMantleError se il servizio prevede un oggetto in risposta nei casi di errore.
 *
 *  Per definire il mapping dell'errore si deve reimplementare il metodo di MTLMMTLJSONSerializingodel +(NSDictionary*)JSONKeyPathsByPropertyKey.
 */
@interface SDServiceMantleError : MTLModel<MTLJSONSerializing, SDServiceGenericErrorProtocol>

@end