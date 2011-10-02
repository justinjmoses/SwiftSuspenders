/*
 * Copyright (c) 2009-2011 the original author or authors
 * 
 * Permission is hereby granted to use, modify, and distribute this file 
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.swiftsuspenders.injectionpoints
{
	import org.swiftsuspenders.InjectionRule;
	import org.swiftsuspenders.Injector;
	import org.swiftsuspenders.InjectorError;
	import org.swiftsuspenders.utils.SsInternal;

	public class PropertyInjectionPoint extends InjectionPoint
	{
		//----------------------       Private / Protected Properties       ----------------------//
		private var _propertyName : String;
		private var _injectionConfig : InjectionPointConfig;


		//----------------------               Public Methods               ----------------------//
		public function PropertyInjectionPoint(config : InjectionPointConfig, propertyName : String)
		{
			_propertyName = propertyName;
			_injectionConfig = config;
		}
		
		override public function applyInjection(
				target : Object, targetType : Class, injector : Injector) : void
		{
			var rule : InjectionRule =
					injector.SsInternal::getMapping(_injectionConfig.mappingId);
			var injection : Object = rule && rule.apply(targetType, injector);
			if (injection == null)
			{
				if (_injectionConfig.optional)
				{
					return;
				}
				throw(new InjectorError(
						'Injector is missing a rule to handle injection into property "' +
						_propertyName +
						'" of object "' + target + '" with type "' + targetType +
						'". Target dependency: "' + _injectionConfig.mappingId + '"'));
			}
			target[_propertyName] = injection;
		}
	}
}