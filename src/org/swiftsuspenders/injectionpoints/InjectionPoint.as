/*
 * Copyright (c) 2009-2011 the original author or authors
 *
 * Permission is hereby granted to use, modify, and distribute this file 
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.swiftsuspenders.injectionpoints
{
	import org.swiftsuspenders.Injector;

	public class InjectionPoint
	{
		//----------------------               Public Methods               ----------------------//
		public function InjectionPoint()
		{
		}
		
		public function applyInjection(target : Object, injector : Injector) : Object
		{
			return target;
		}
	}
}