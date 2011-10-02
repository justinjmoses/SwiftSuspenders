/*
 * Copyright (c) 2009-2011 the original author or authors
 *
 * Permission is hereby granted to use, modify, and distribute this file
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.swiftsuspenders
{
	import flash.system.ApplicationDomain;
	import flash.utils.describeType;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;

	import org.swiftsuspenders.injectionpoints.ConstructorInjectionPoint;
	import org.swiftsuspenders.injectionpoints.InjectionPoint;
	import org.swiftsuspenders.injectionpoints.InjectionPointConfig;
	import org.swiftsuspenders.injectionpoints.MethodInjectionPoint;
	import org.swiftsuspenders.injectionpoints.NoParamsConstructorInjectionPoint;
	import org.swiftsuspenders.injectionpoints.PostConstructInjectionPoint;
	import org.swiftsuspenders.injectionpoints.PropertyInjectionPoint;
	import org.swiftsuspenders.utils.InjectionPointsConfigMap;

	public class DescribeTypeReflector extends ReflectorBase implements Reflector
	{
		//----------------------       Private / Protected Properties       ----------------------//
		private var _currentType : Class;
		private var _currentFactoryXML : XML;
		private var _configMap : InjectionPointsConfigMap;

		//----------------------               Public Methods               ----------------------//
		public function classExtendsOrImplements(classOrClassName : Object,
			superclass : Class, application : ApplicationDomain = null) : Boolean
		{
            var actualClass : Class;
			
            if (classOrClassName is Class)
            {
                actualClass = Class(classOrClassName);
            }
            else if (classOrClassName is String)
            {
                try
                {
                    actualClass = Class(getDefinitionByName(classOrClassName as String));
                }
                catch (e : Error)
                {
                    throw new Error("The class name " + classOrClassName +
                    	" is not valid because of " + e + "\n" + e.getStackTrace());
                }
            }

            if (!actualClass)
            {
                throw new Error("The parameter classOrClassName must be a valid Class " +
                	"instance or fully qualified class name.");
            }

            if (actualClass == superclass)
                return true;

            var factoryDescription : XML = describeType(actualClass).factory[0];

			return (factoryDescription.children().(
            	name() == "implementsInterface" || name() == "extendsClass").(
            	attribute("type") == getQualifiedClassName(superclass)).length() > 0);
		}

		public function startReflection(type : Class, configMap : InjectionPointsConfigMap) : void
		{
			_currentType = type;
			_configMap = configMap;
			_currentFactoryXML = describeType(type).factory[0];
		}

		public function endReflection() : void
		{
			_currentType = null;
			_configMap = null;
			_currentFactoryXML = null;
		}

		public function getCtorInjectionPoint() : ConstructorInjectionPoint
		{
			const node : XML = _currentFactoryXML.constructor[0];
			if (!node)
			{
				if (_currentFactoryXML.parent().@name == 'Object'
						|| _currentFactoryXML.extendsClass.length() > 0)
				{
					return new NoParamsConstructorInjectionPoint();
				}
				return null;
			}
			var nameArgs : XMLList = node.parent().metadata.arg.(@key == 'name');
			/*
			 In many cases, the flash player doesn't give us type information for constructors until
			 the class has been instantiated at least once. Therefore, we do just that if we don't get
			 type information for at least one parameter.
			 */
			if (node.parameter.(@type == '*').length() == node.parameter.@type.length())
			{
				createDummyInstance(node, _currentType);
			}
			const parameters : Array = gatherMethodParameters(node.parameter, nameArgs);
			const requiredParameters : uint = parameters.required;
			delete parameters.required;
			return new ConstructorInjectionPoint(parameters, requiredParameters);
		}

		public function addFieldInjectionPointsToList(
				lastInjectionPoint : InjectionPoint) : InjectionPoint
		{
			for each (var node : XML in _currentFactoryXML.*.
					(name() == 'variable' || name() == 'accessor').metadata.(@name == 'Inject'))
			{
				var config : InjectionPointConfig =
						_configMap.getInjectionPointConfig(node.parent().@type,
						node.arg.(@key == 'name').attribute('value'));
				var propertyName : String = node.parent().@name;
				var injectionPoint : PropertyInjectionPoint = new PropertyInjectionPoint(
						config, propertyName, getOptionalFlagFromXMLNode(node));
				lastInjectionPoint.next = injectionPoint;
				lastInjectionPoint = injectionPoint;
			}
			return lastInjectionPoint;
		}

		public function addMethodInjectionPointsToList(
				lastInjectionPoint : InjectionPoint) : InjectionPoint
		{
			for each (var node : XML in _currentFactoryXML.method.metadata.(@name == 'Inject'))
			{
				const nameArgs : XMLList = node.arg.(@key == 'name');
				const parameters : Array =
						gatherMethodParameters(node.parent().parameter, nameArgs);
				const requiredParameters : uint = parameters.required;
				delete parameters.required;
				var injectionPoint : MethodInjectionPoint =
						new MethodInjectionPoint(node.parent().@name, parameters,
								requiredParameters, getOptionalFlagFromXMLNode(node));
				lastInjectionPoint.next = injectionPoint;
				lastInjectionPoint = injectionPoint;
			}
			return lastInjectionPoint;
		}

		public function addPostConstructMethodPointsToList(
				lastInjectionPoint : InjectionPoint) : InjectionPoint
		{
			const postConstructMethodPoints : Array = [];
			for each (var node : XML in
					_currentFactoryXML.method.metadata.(@name == 'PostConstruct'))
			{
				var order : Number = parseInt(node.arg.(@key == 'order').@value);
				postConstructMethodPoints.push(new PostConstructInjectionPoint(
						node.parent().@name, isNaN(order) ? int.MAX_VALUE : order));
			}
			if (postConstructMethodPoints.length > 0)
			{
				postConstructMethodPoints.sortOn('order', Array.NUMERIC);
				for each (var injectionPoint : InjectionPoint in postConstructMethodPoints)
				{
					lastInjectionPoint.next = injectionPoint;
					lastInjectionPoint = injectionPoint;
				}
			}
			return lastInjectionPoint;
		}

		//----------------------         Private / Protected Methods        ----------------------//
		private function getOptionalFlagFromXMLNode(node : XML) : Boolean
		{
			return node.arg.(@key == 'optional' &&
					(@value == 'true' || @value == '1')).length() != 0;
		}

		private function gatherMethodParameters(
				parameterNodes : XMLList, nameArgs : XMLList) : Array
		{
			var requiredParameters : uint = 0;
			const length : uint = parameterNodes.length();
			const parameters : Array = new Array(length);
			for (var i : int = 0; i < length; i++)
			{
				var parameter : XML = parameterNodes[i];
				var injectionName : String = '';
				if (nameArgs[i])
				{
					injectionName = nameArgs[i].@value;
				}
				var parameterTypeName : String = parameter.@type;
				var optional : Boolean = parameter.@optional == 'true';
				if (parameterTypeName == '*')
				{
					if (!optional)
					{
						//TODO: Find a way to trace name of affected class here
						throw new InjectorError('Error in method definition of injectee. ' +
								'Required parameters can\'t have type "*".');
					}
					else
					{
						parameterTypeName = null;
					}
				}
				if (!optional)
				{
					requiredParameters++;
				}
				parameters[i] = _configMap.getInjectionPointConfig(
						parameterTypeName, injectionName);
			}
			parameters.required = requiredParameters;
			return parameters;
		}

		private function createDummyInstance(constructorNode : XML, clazz : Class) : void
		{
			try
			{
				switch (constructorNode.children().length())
				{
					case 0 :(new clazz());break;
					case 1 :(new clazz(null));break;
					case 2 :(new clazz(null, null));break;
					case 3 :(new clazz(null, null, null));break;
					case 4 :(new clazz(null, null, null, null));break;
					case 5 :(new clazz(null, null, null, null, null));break;
					case 6 :(new clazz(null, null, null, null, null, null));break;
					case 7 :(new clazz(null, null, null, null, null, null, null));break;
					case 8 :(new clazz(null, null, null, null, null, null, null, null));break;
					case 9 :(new clazz(null, null, null, null, null, null, null, null, null));break;
					case 10 :
						(new clazz(null, null, null, null, null, null, null, null, null, null));
						break;
				}
			}
			catch (error : Error)
			{
				trace('Exception caught while trying to create dummy instance for constructor ' +
						'injection. It\'s almost certainly ok to ignore this exception, but you ' +
						'might want to restructure your constructor to prevent errors from ' +
						'happening. See the SwiftSuspenders documentation for more details. ' +
						'The caught exception was:\n' + error);
			}
			constructorNode.setChildren(describeType(clazz).factory.constructor[0].children());
		}
	}
}